function create_class_table_ids(carboxysomes, outfile)
% This function produces an output CSV file with data from a carboxysome
% array output after running the main pipeline. Specifically lists each
% rubisco with information about chains and chain partners.
% It is a modified version of the create_class_table.m file in
% helper_functions/

% Input is the Carboxysome array obtained after running chain_maker
% Second argument is the name of the outfile including CSV
% Usage: create_class_table_revised_ids(carb_list, 'my_output_carb_table.CSV');

    
    % Open a file for writing
    fid = fopen(outfile, 'w');
    

    % Write the header
    fprintf(fid, ['particle_ID,carboxysome_ID,carboxysome_volume um^3,carboxysome_total_concentration uM,carboxysome_inner_rubisco_concentration uM,outer_rubisco_1/0,chain_1/0,chain index,central_lattice_1/0,oligomerization_partner_1,oligomerization_partner_2,oligomerization_partner_3,oligomerization_partner_4,oligomerization_partner_5,oligomerization_partner_6,oligomerization_partner_7,oligomerization_partner_8,oligomerization_partner_9,oligomerization_partner_10,distance_to_upper_chain_partner pix,distance_to_lower_chain_partner pix,distance_lateral_to_nearest_chain pix,twist_above deg,twist_below deg,bend_above deg,bend_below deg\n']);
    
    % Iterate through each Carboxysome
    rubisco_count = 1;
    for carb_idx = 1:length(carboxysomes)
        carb = carboxysomes(carb_idx);
        
        % Iterate through each Rubisco in the Carboxysome
        for rubisco_idx = 1:carb.num_rubisco
            rubisco = carb.rubisco(rubisco_idx);
            
            % Basic information
            rubisco_count = rubisco_count + 1;
            particle_ID = rubisco.tag;
            carboxysome_ID = carb.carb_index;
            carboxysome_volume = carb.volume * 10^18; % in cubic micrometers
            carboxysome_total_concentration = carb.concentration; % in micromolar
            carboxysome_inner_concentration = carb.inner_concentration; % in micromolar
            
            % Check if Rubisco is outer (1) or inner (0)
            outer_rubisco = rubisco.inside == 0;
            
            % Check if Rubisco is in a chain
            in_chain = 0;
            in_central_chain = 0;
            chain_idx = [];
            chain_tag = 0;
            chain_partners = zeros(1, 10);
            distAbove = nan;
            distBelow = nan;
            distLateral = nan;
            twistAbove = nan;
            twistBelow = nan;
            bendAbove = nan;
            bendBelow = nan;
            
            % Check if rubisco is in a chain
            for chain = carb.chains
                if ismember(rubisco.tag, chain.tags)
                    chain_idx = chain; % the chain object the rubisco is in
                    chain_tag = chain.tag;
                end
            end

            if ~isempty(chain_idx) % if the rubisco is in a chain

                in_chain = 1;
                chain_lead_vector = chain_idx.average_vector;
                chain_partners(1:length(chain_idx.tags)) = chain_idx.tags(:);

                if ~isnan(rubisco.rubisco_above_me)
                    rubisco_above = carb.rubisco(find([carb.rubisco.tag] == rubisco.rubisco_above_me));
                    dist_vec = [rubisco_above.x rubisco_above.y rubisco_above.z] - [rubisco.x rubisco.y rubisco.z];
                    distAbove = dot(dist_vec, rubisco.vector)/norm(rubisco.vector);
                    % Calculate twist and bend between this rubisco and the
                    % one above it in external modularized functions
                    twistAbove = calc_twist(rubisco, rubisco_above, chain_lead_vector);
                    bendAbove = calc_bend(rubisco, rubisco_above);
                end
                
                if ~isnan(rubisco.rubisco_below_me)
                    rubisco_below = carb.rubisco(find([carb.rubisco.tag] == rubisco.rubisco_below_me));
                    dist_vec = [rubisco_below.x rubisco_below.y rubisco_below.z] - [rubisco.x rubisco.y rubisco.z];
                    distBelow = dot(dist_vec, rubisco.vector)/norm(rubisco.vector);
                    % Calculate twist and bend between this rubisco and the
                    % one below it in external modularized functions
                    twistBelow = calc_twist(rubisco_below, rubisco, chain_lead_vector);
                    bendBelow = calc_bend(rubisco, rubisco_below);
                end

                distLateral = min([carb.chain_links(find([carb.chain_links.I_index] == chain_idx.index | [carb.chain_links.J_index] == chain_idx.index)).distance]);
                if isempty(distLateral)
                    distLateral = nan;
                end

                in_central_chain = rubisco.in_central_chain;
            end
            
            % Write the data to the CSV file
            fprintf(fid, '%d,%d,%.10e,%.10f,%.10f,%d,%d,%d,%d', ... %Between in_chain and in_central_chain added chain_index
                particle_ID, carboxysome_ID, carboxysome_volume, carboxysome_total_concentration, ...
                carboxysome_inner_concentration, outer_rubisco, in_chain, chain_tag, in_central_chain);
            
            % Write oligomerization partners
            for i = 1:10 % Might need to change to 11 (?) - note change of including self rubisco in table
                fprintf(fid, ',%d', chain_partners(i));
            end
            
            % Write distances and angles
            fprintf(fid, ',%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n', ...
                distAbove, distBelow, distLateral, twistAbove, twistBelow, bendAbove, bendBelow);
        end
    end
    
    % Close the file
    fclose(fid);
    
    disp('CSV file has been created');
end