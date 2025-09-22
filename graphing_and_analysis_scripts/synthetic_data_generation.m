function synthetic_data_generation()
	% Note: For our rubisco standard tables, volume index is 21, coordinates is 24, and angles is 7.
    % Generation of random particles & angles
    disp('This script will generate random particles with customized  parameters based on an existing input file to determine volumes?');
    
    particle_diameter = input('Enter particle diameter in meters using scientific notation (e.g. 9.36e-9)\n> '); 
    input_file = input('Enter input file path (e.g. ''data/wildType.tbl'')\n> ', 's');

    outfile = input('Enter output file path with file name (e.g. data/synthetic_data.tbl)\n> ', 's');


    input_tbl = dread(input_file);
    volume_index_col = input('Enter the column number for the volume index (this will be 21 for dynamo tables)\n> ');
    volumes = input_tbl(:, volume_index_col);
    coordinate_col = input('Enter the column for the x-coordinate. This program assumes the y and z coordinate columns follow directly after. This will be 24 for dynamo tables.\n >');
    coordinates = input_tbl(:, coordinate_col:coordinate_col+2);
    angles_col = input('Enter the column for the first angle. This program assumes the other 2 angles follow directly after. This will be 7 for dynamo tables.\n> ');

    unique_volume_ids = unique(volumes);

    all_particles = [];
    all_angles = [];

    for i = 1:length(unique_volume_ids)
        current_volume = unique_volume_ids(i);
        mask_particles = (volumes == current_volume);
        matching_rows = coordinates(mask_particles, :);
        sum_particles_in_volume = sum(mask_particles);
        center = mean(matching_rows, 1);
        all_distances_from_center = sqrt(sum((matching_rows - center).^2, 2));
        approx_radius = max(all_distances_from_center);

        particles = generate_particles_in_sphere(center, approx_radius, particle_diameter/2, sum_particles_in_volume);
        angles = generate_euler_angles(sum_particles_in_volume);
        
        all_particles = [all_particles; particles];
        all_angles = [all_angles; angles];
    end

    
    disp('Generated all random particles. Writing to outfile.');
    output_tbl = input_tbl;
    output_tbl(:, coordinate_col:coordinate_col + 2) = all_particles;
    output_tbl(:, angles_col:angles_col + 2) = all_angles;
    
    try
        dwrite(output_tbl, outfile);
    catch ME
        disp('Failed to write to outfile.');
    end



    disp('Now beginning filament generation.');
    disp('You can cancel the script now if you only wish for random particles to be generated.');
    
    
    num_filaments = input('Enter number of filaments per volume\n> ');
    min_filament_length = input('Enter min number of particles in filament\n> ');
    max_filament_length = input('Enter max number of particles in filament\n> ');

    particle_spacing = input('Enter the distance between consecutive particles in meters. Typically 2 times the diamater is good. Use scientific notation (e.g. 1.987e-8) \n>' );
    jitter = input('Enter jitter amount. This is translational shifts in meters. Start with half the diameter for testing. (e.g. 4.968e-9) \n> ');
    twist = input('Enter twist amount in the amount of degrees from 0 to 90. We use a max of 45 for D4 proteins. \n> ');
    bend = input('Enter bend amount in degrees. For rubisco 20 our max. \n> ');

    output_file = input('Enter the output file for the filament data. \n >', 's');
    new_particle_info_volumes = {};
    mask_remove = false(size(output_tbl, 1), 1);

    for i = 1:length(unique_volume_ids)
        new_coords = [];
        new_angles = [];
        current_volume = unique_volume_ids(i);
        mask_particles = (volumes == current_volume);
        matching_rows = all_particles(mask_particles, :);
    
        center = mean(matching_rows, 1);
        for f=1:num_filaments
            % Filament generation 
            filament_len = randi([min_filament_length, max_filament_length]);
            filament_coord = [];
            filament_angle = [];
    
            direction = randn(1,3);
            direction = direction/norm(direction); % normalize to make it uniform
    
            % initialize the first particle angle
            yaw = atan2d(direction(2), direction(1));
            inclination = acosd(direction(3));
            twist_val = (rand * 2 - 1) * twist;
            filament_angle(1, :) = [yaw, inclination, twist_val];
            filament_coord(1, :) = [0,0,0];

            for j=2:filament_len
                % bend calc
                bend_factor = rand * bend / 90;
                if bend_factor > 0
                    shift_dir = cross(direction, randn(1,3));
                    if norm(shift_dir) > 0.000001 % divide by 0 check
                        shift_dir = shift_dir / norm(shift_dir);
                        direction = direction + bend_factor * shift_dir;
                        direction = direction / norm (direction);
                    end
                end
                
                % jitter calc
                next_coord = filament_coord(j-1, :) + particle_spacing * direction;
                jitter_vector = (rand(1,3) - 0.5) * jitter;
                filament_coord(j, :) = next_coord + jitter_vector;
    
                % twist & euler angle conversion from cartesian
                yaw = atan2d(direction(2), direction(1));
                inclination = acosd(direction(3));
                twist_val = (rand * 2 - 1)* twist; % shift to make it -90 to 90 range
                
                filament_angle(j, :)= [yaw, inclination, twist_val];
            end
            filament_coord = filament_coord - mean(filament_coord, 1) + center;
            
            new_coords = [new_coords; filament_coord];
            new_angles = [new_angles; filament_angle];
        end

        % remove excess/overlap
        if ~isempty(new_coords) 
            original_coords = output_tbl(mask_particles, coordinate_col:coordinate_col+2);
            original_index = find(mask_particles);
            
            collisions = [];
            for new_i=1:size(new_coords)
                new_pos = new_coords(new_i, :);
                for original_i=1:size(original_coords)
                    original_pos = original_coords(original_i, :);

                    distance = sum((new_pos - original_pos).^2);
                    if distance < particle_diameter^2
                        collisions(end+1) = original_index(original_i);
                    end
                end
            end
            if ~isempty(collisions)
                unique_removals = unique(collisions);
                mask_remove(unique_removals) = true;
            end
            all_new = size(new_coords, 1);
            new_particle_info = [new_coords, new_angles, repmat(current_volume, all_new, 1)];
            new_particle_info_volumes{end + 1} = new_particle_info;
        end
    end

    % Clean up the collisions
    final_output = output_tbl(~mask_remove, :);
    if ~isempty(new_particle_info_volumes)
        all_new_particles = cat(1, new_particle_info_volumes{:});
        total = size(all_new_particles, 1);

        column_total = size(output_tbl, 2);
        new_rows = zeros(total, column_total);
        new_rows(:, coordinate_col:coordinate_col+2) = all_new_particles(:, 1:3);
        new_rows(:, angles_col:angles_col+2) = all_new_particles(:, 4:6);
        new_rows(:, volume_index_col) = all_new_particles(:, 7);

        final_output = [final_output; new_rows];
    end
    try
        dwrite(final_output, output_file);
    catch ME
        disp('Failed to write to the output file.');
    end
    return


end

function particles = generate_particles_in_sphere(center, sphere_radius, particle_radius, num_particles)    
    particles = zeros(num_particles, 3);
    maximum_radius = sphere_radius - particle_radius; 

    for i = 1:num_particles
        attempts = 0;
        max_attempts = 1000;
        
        while attempts < max_attempts 
            % Uses rejection method, may not be as efficient with high number of particles/volume

            % Math for the coordinate picking is from
            % https://math.stackexchange.com/questions/87230/picking-random-points-in-the-volume-of-sphere-with-uniform-probability/87238#87238
            x = randn();
            y = randn();
            z = randn();
            normalize = sqrt(x^2 + y^2 + z^2);
            x = x / normalize;
            y = y / normalize;
            z = z / normalize;
            u_rand = rand();
            c = u_rand^(1/3) * maximum_radius;
            x = x * c;
            y = y * c;
            z = z * c;

            % Adjust the coordinate by some shift
            candidate = center + [x, y, z];
           
            if i == 1
                particles(i, :) = candidate;
                break;
            else
                distances = sqrt(sum((particles(1:i-1, :) - candidate).^2, 2));
                if all(distances >= particle_radius * 2)  % If no overlap
                    particles(i, :) = candidate;
                    break;
                end
            end
            attempts = attempts + 1;
        end
        
        if attempts >= max_attempts
            warning('Could not place particle %d without overlap, too many attempts.', i);
        end
    end

end

function angles = generate_euler_angles(num_particles)
    angles = zeros(num_particles, 3);
    angles(:,1) = 360 * rand(num_particles, 1) - 180;
    angles(:,2) = 180 * rand(num_particles, 1);
    angles(:,3) = 360 * rand(num_particles, 1) - 180;
end

