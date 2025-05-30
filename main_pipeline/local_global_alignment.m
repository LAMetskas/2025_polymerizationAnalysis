function carboxysome_data = local_global_alignment(filename, carboxysomes, max_distance)
% Calculate the pairwise distance and angle between each pair of Rubiscos
% within a carboxysome. carboxysomes is an array of Carboxysome Objects
% which contain the necessary rubisco data. If neceassary, can read data
% directly from file filename by inputing filename as the only argument. 
% Also calculate the global alignment of each carboxysome using tensor
% analysis.
%
% local_global_alignment.m © 2025 is licensed under CC BY-NC-SA 4.0

    %% import useful data
    % Allow the user to run this script as a starting point, will call
    % the previous scripts in the pipeline and obtain the necessary data
    if nargin == 1
        carboxysomes = convex_hull_and_volume(filename);
    end
    
    %% important constants
    % load constants from external file. change constants in file depending
    % on the dataset being used
    CONSTANTS = constants();
    rubisco_diameter = CONSTANTS.RUBISCO_DIAMETER_M / CONSTANTS.PIXEL_SIZE;

    if nargin < 3 % max distance will be twice the rubisco diameter by default
        max_distance = 2*rubisco_diameter;
    end
    
    %% Create pairs based on proximity using spatial hashing
    num_carb = length(carboxysomes);
    all_viable_pairs = Rubisco_Pair.empty;
    
    % Anonymous function to convert a numerical array to a string key
    arrayToStringKey = @(array) mat2str(array);
    
    % Anonymous function to convert a string key back to a numerical array
    stringKeyToArray = @(strKey) str2num(strKey);
    
    for g = 1:num_carb
        disp(g);
        carb = carboxysomes(g);
        rubisco_pairs = Rubisco_Pair.empty;
        vol = carb.volume;
        num_rubisco_inner = carb.num_rubisco_inner;
        num_rubisco = carb.num_rubisco;
        vectors = zeros(length(carb.rubisco),3);
        rubiscos = carb.rubisco;
            
        % Spatial Hashing: Loop once here across all rubisco in the carboxysome 
        % (for i = 1:num_rubisco) and find minimum and maximum possible x, y, and z 
        % coordinate of rubisco position.

        lowest = [rubiscos(1).x rubiscos(1).y rubiscos(1).z];
    
        for j = 2:length(rubiscos)
            if rubiscos(j).x < lowest(1)
                lowest(1) = rubiscos(j).x;
            end
            if rubiscos(j).y < lowest(2)
                lowest(2) = rubiscos(j).y;
            end
            if rubiscos(j).z < lowest(3)
                lowest(3) = rubiscos(j).z;
            end
        end

        % SH: we will do one pass over all rubisco in the carboxysome (linear time)
        % here where we will hash the rubisco particle to determine which
        % voxel it is in. We will later use this to find all neighboring rubisco.
    
        voxels = containers.Map();
    
        for k = 1:length(rubiscos)
            rubisco_outer_list = rubiscos(k);
            vector = compute_vector(rubisco_outer_list);
            rubisco_outer_list.vector = vector;
            rubisco_outer_list.index = k;
            vectors(k, :) = vector; % each row corresponds to the orientation of the kth rubisco
            
            rel_pos = [rubisco_outer_list.x rubisco_outer_list.y rubisco_outer_list.z] - lowest;
    
            box = ceil(rel_pos / max_distance);
            stringBox = arrayToStringKey(box);
            if ~isKey(voxels, stringBox)
                voxels(stringBox) = k;
            else
                voxels(stringBox) = [voxels(stringBox) k];
            end
        end
    
        stringBoxes = voxels.keys;
    
        values = [-1 0 1];
    
        [grid1, grid2, grid3] = ndgrid(values, values, values);
    
        % Combine grids into a matrix
        permutations_matrix = [grid1(:), grid2(:), grid3(:)];
        % Remove the row where all elements are zero (i.e., [0 0 0]) to
        % exclude the rubisco inside the current voxel from the list of
        % rubisco in the voxels around (3D: 26 boxes) the current
        permutations_matrix = permutations_matrix(~all(permutations_matrix == 0, 2), :);

        % Set data structure to store pairs of rubisco across different
        % voxels and make sure no duplicates are created.
        pairs_across_voxels = containers.Map();
    
        for stringBox = stringBoxes
            box = stringKeyToArray(stringBox{1});
            boxes = box + permutations_matrix;
            rubisco_outer_list = Rubisco.empty;
            rubisco_inner_list = Rubisco.empty;
    
            for index = voxels(stringBox{1})
                rubisco_inner_list(end+1) = rubiscos(index);
            end
    
            for permutation = boxes'
                stringPermutation = arrayToStringKey(permutation');
                if ismember(stringPermutation, stringBoxes)
                    for index = voxels(stringPermutation)
                        rubisco_outer_list(end+1) = rubiscos(index);
                    end
                end
            end
                
            % Create all pairs from within the current voxel (no distance
            % check necessary since voxel size is small enough). All pairs
            % will be 'valid'.
            for i = 1:length(rubisco_inner_list)-1
                rubisco_I = rubisco_inner_list(i);
                is_inner_I = ismember(rubisco_I.tag, carb.tags_inside);
                for j = i + 1:length(rubisco_inner_list)
                    rubisco_J = rubisco_inner_list(j);

                    angle = calc_angle(rubisco_I.vector, rubisco_J.vector);

                    is_inner_J = ismember(rubisco_J.tag, carb.tags_inside);
                    inner = is_inner_I && is_inner_J;
                    
                    % Calculate distance anyway since it is needed for
                    % filtering in linkages.m. In the future we may attempt
                    % to combine local_global_alignment and linkages so
                    % that we may skip this calculation.
                    distance = calc_distance(rubisco_I, rubisco_J);
    
                    pair = Rubisco_Pair(carb.carb_index, num_rubisco, num_rubisco_inner, ...
                        vol, inner, rubisco_I.index, rubisco_J.index, rubisco_I.tag, ...
                        rubisco_J.tag, angle, distance, carb.concentration, carb.inner_concentration);

                    projection = calc_projection(rubisco_I, rubisco_J);
                    pair.projection = projection;

                    rubisco_pairs(end+1) = pair;
                end
            end
            
            % make all pairs of rubisco across the current voxel and
            % surrounding voxels (in case rubisco is close enough to the
            % edge of its voxel). Distance check necessary.
            for rubisco_I = rubisco_inner_list
                is_inner_I = ismember(rubisco_I.tag, carb.tags_inside);
                for rubisco_J = rubisco_outer_list
                    % There may be duplicate pairs as each voxel will be
                    % checked for pairs with rubisco in surrounding voxels
                    % individually, so adjacent voxels will be checked in
                    % both directions. Duplicate pairs will have the
                    % rubisco tags flipped as for the duplicate we will be
                    % checking the pair in the opposite direction. Check if
                    % the pair with flipped tags has already been created
                    % and if so skip and don't create a duplicate.
                    % Otherwise, add this new pair to the created set.
                    if isKey(pairs_across_voxels, arrayToStringKey([rubisco_J.tag, rubisco_I.tag]))
                        continue
                    else
                        pairs_across_voxels(arrayToStringKey([rubisco_I.tag, rubisco_J.tag])) = true;
                    end

                    distance = calc_distance(rubisco_I, rubisco_J);
                    if distance > max_distance * 1.732 % to allow the edges of this sphere to encapsulate the cube, must multiply by root 3 
                        continue
                    end

                    angle = calc_angle(rubisco_I.vector, rubisco_J.vector);
                   
                    is_inner_J = ismember(rubisco_J.tag, carb.tags_inside);
                    inner = is_inner_I && is_inner_J;
    
                    pair = Rubisco_Pair(carb.carb_index, num_rubisco, num_rubisco_inner, ...
                        vol, inner, rubisco_I.index, rubisco_J.index, rubisco_I.tag, ...
                        rubisco_J.tag, angle, distance, carb.concentration, carb.inner_concentration);

                    projection = calc_projection(rubisco_I, rubisco_J);
                    pair.projection = projection;
            
                    rubisco_pairs(end+1) = pair;
                end
            end
        end
        
        carb.rubisco_pairs = rubisco_pairs;
        all_viable_pairs = [all_viable_pairs, rubisco_pairs];
    end
    
    %% find aligned vs. carboxysome data
    angle_interval = [0 25];
    for carb = carboxysomes
        events = carb.rubisco_pairs;
        events = events([events.inner]); % filter by inner
        events = events([events.distance] < 2*rubisco_diameter); % filter by distance check
        events = events([events.angle] < angle_interval(2));
    
        if ~isempty(events)
            carb.num_events = length(events);
        end   
    end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%GLOBAL ALIGNMENT%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %% find average vector for each carboxysome
    for carb = carboxysomes
        carb.ave_vector = calc_average_vector(carb, true);
    end
    
    %% find S orientation tensor for each carboxysome
    for carb = carboxysomes
        if carb.num_rubisco_inner > 0
            carb.S = op(carb, true);
            carb.eigenvalues = eigs(carb.S);
            carb.S_val = (3/2)*max(carb.eigenvalues);
        end
    end
    
    % assign for function output
    carboxysome_data = carboxysomes;
    
    %% helper functions
    function vector = compute_vector(rubisco)
    % compute the vector for a rubisco orientation
        initial_vector = [0 0 1];
        z_mat = z_rot_matrix(rubisco.tdrot);
        x_mat = x_rot_matrix(rubisco.tilt);
        vector = (initial_vector*x_mat)*z_mat;
    end
    
    function mat = x_rot_matrix(theta)
    % calculate the rotation matrix about the x axis for a rotation of
    % theta degrees.
        theta = (pi*theta)/ 180;
        mat = [1 0 0;
            0 cos(theta) -sin(theta);
            0 sin(theta) cos(theta)];
    end
    
    function mat = z_rot_matrix(theta)
    % calculate the rotation matrix about the z axis for a rotation of
    % theta degrees.
        theta = (pi*theta)/ 180;
        mat = [cos(theta) -sin(theta) 0;
            sin(theta) cos(theta) 0;
            0 0 1];
    end
    
    function angle = calc_angle(vec1, vec2)
    % calculate the angle in degrees between two vectors vec1 and vec2 in R^3
        angle = acos(abs(dot(vec1, vec2)/(norm(vec1)*norm(vec2)))) * (180/pi);
    end
    
    function distance = calc_distance(rubisco1, rubisco2)
    % calculate the euclidean norm between rubiscos rubisco1 and rubisco2
        distance = norm([rubisco1.x rubisco1.y rubisco1.z] - [rubisco2.x rubisco2.y rubisco2.z]);
    end

    function projection = calc_projection(rubisco1, rubisco2)
    % calculate the minimum projection between two rubiscos
        dist_vec = [rubisco1.x rubisco1.y rubisco1.z] - [rubisco2.x rubisco2.y rubisco2.z];
        vec1 = rubisco1.vector;
        projection = dot(dist_vec, vec1)/norm(vec1);
    end
    
    function S = calc_S(vector)
    % compute the S alignment tensor for a rubisco
        S = vector' * vector;
        S = S - (1/3)*[1 0 0; 0 1 0; 0 0 1];
    end
    
    function S = op(carb, inner_only)
    % compute average S tensor for a carboxysome
        all_rubiscos = carb.rubisco;
        len = length(all_rubiscos(1).vector);
        
        % filter out outer carboxysomes if inner_only is true
        if inner_only; all_rubiscos = all_rubiscos(ismember([all_rubiscos.tag], [carb.tags_inside])); end
        
        S = zeros(len, len);
        for n = 1:length(all_rubiscos)
            S = S + calc_S(all_rubiscos(n).vector);
        end
        S = S/length(all_rubiscos);
    end
    
    function ave_vec = calc_average_vector(carb, inner_only)
    % compute the average vector for a carboxysome
        vec = [0 0 0];
        all_rubiscos = carb.rubisco;
        if inner_only; all_rubiscos = all_rubiscos(ismember([all_rubiscos.tag], [carb.tags_inside])); end
        for this_rubisco = all_rubiscos
            tent_vec1 = vec + this_rubisco.vector;
            tent_vec2 = vec - this_rubisco.vector;
            if norm(tent_vec1) > norm(tent_vec2); vec = tent_vec1; else; vec = tent_vec2; end
        end
        ave_vec = vec/length(all_rubiscos);
    
    end
end