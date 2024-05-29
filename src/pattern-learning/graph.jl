function ranking_update!(feature_values::Dict{UInt32, Gaussian}, legals::Vector{Move}, board::Board; loop_eps=1e-3)
    board_values = Vector{Gaussian}()
    sum_factors = Vector{SumFactor}()

    for move in legals
        # do move m on board b to get board b'
        do_move!(board, move)

        # # calculate all legal moves on board b'
        _, legals_prime = generate_legals(board)

        # list to hold all feature value nodes of the board b'
        summands = Vector{Gaussian}()

        # extract all feature hashes of board b' (hashes are used to collect the set of feature value nodes)
        hashes = map(mv_prime -> move_to_hash(mv_prime), legals_prime)

        for i in eachindex(hashes)
            if !haskey(feature_values, hashes[i])
                feature_values[hashes[i]] = GaussianByMeanVariance(0.0, 1.0)
            end

            push!(summands, feature_values[hashes[i]])
            for j in i+1:length(hashes)
                hash = hashes[i] | (hashes[j] << 16)
                # INITIALIZE (UNSEEN) FEATURE NODES WITH STANDARD NORMAL URGENCIES
                if !haskey(feature_values, hash)
                    feature_values[hash] = GaussianByMeanVariance(0.0, 1.0)
                end

                # ADD THE FEATURE VALUE NODE TO THE SUMMANDS LIST OF SUM FACTOR
                push!(summands, feature_values[hash])
            end
        end

        # IF THERE ARE NO LEGAL MOVES, ADD A SPECIAL CHECKMARK FEATURE NODE
        if length(legals_prime) == 0
            if !haskey(feature_values, 0)
                feature_values[0] = GaussianByMeanVariance(0.0, 1.0)
            end
            push!(summands, feature_values[0])
        end

        # INITIALIZE A BOARD VALUE NODE AND A SUM FACTOR AND ADD THEM TO THE RESPECTIVE LISTS
        board_value = GaussianUniform()
        push!(board_values, board_value)
        push!(sum_factors, SumFactor(summands, board_value))

        undo_move!(board, move)
    end
    
    # INITIALIZE LATENT VALUES AND FACTORS

    latent_values = Vector{Gaussian}()
    gaussian_mean_factors = Vector{GaussianMeanFactor}()

    for i in eachindex(board_values)
        latent_value = GaussianUniform()
        push!(latent_values, latent_value)
        push!(gaussian_mean_factors, GaussianMeanFactor(latent_value, board_values[i], 0.5))
    end

    # INITIALIZE DIFFS, DIFFERENCE FACTORS AND GREATER THAN FACTORS

    difference_values = Vector{Gaussian}()
    difference_factors = Vector{DifferenceFactor}()
    greather_than_factors = Vector{GreaterThanFactor}()

    for i in 2:length(latent_values)
        diff = GaussianUniform()
        push!(difference_values, diff)
        push!(difference_factors, DifferenceFactor(latent_values[1], latent_values[i], diff))
        push!(greather_than_factors, GreaterThanFactor(diff))
    end

    #############################################
    # SUM PRODUCT ALGORITHM

    # FORWARD-PASS: BOARD VALUES
    for (i, factor) in enumerate(sum_factors)
        update_msg_to_sum!(factor)
        # if isnan(gmean(factor.sum)) || isnan(variance(factor.sum))
        #     error("NaN in sum factor forward pass $i")
        # end
    end


    # FORWARD-PASS: LATENT VALUES
    for (i, factor) in enumerate(gaussian_mean_factors)
        update_msg_to_x!(factor)
        # if isnan(gmean(factor.x)) || isnan(variance(factor.x))
        #     error("NaN in gaussian mean factor forward pass $i")
        # end
    end

    # RUN UNTIL LOOP CONVERGES
    ϵ = 10 * loop_eps
    while ϵ > loop_eps
        ϵ = 0.0
        for (i, factor) in enumerate(difference_factors)
            ϵ = max(ϵ, update_msg_to_z!(factor))
            ϵ = max(ϵ, update_msg_to_x!(greather_than_factors[i]))
            ϵ = max(ϵ, update_msg_to_x!(factor))
        end
    end

    # BACKPASS: LATENT VALUES
    for (i, factor) in enumerate(difference_factors)
        update_msg_to_y!(factor)
        # if isnan(gmean(factor.y)) || isnan(variance(factor.y))
        #     error("NaN in difference factor backward pass $i")
        # end
    end

    # BACKPASS: BOARD VALUES
    for (i, factor) in enumerate(gaussian_mean_factors)
        update_msg_to_y!(factor)
        # if isnan(gmean(factor.y)) || isnan(variance(factor.y))
        #     error("NaN in gaussian mean factor backward pass $i")
        # end
    end

    # UPDATE URGENCIES
    for (i, factor) in enumerate(sum_factors)
        for j in eachindex(factor.summands)
            update_msg_to_summand!(factor, j)

            # if isnan(gmean(factor.summands[j])) || isnan(variance(factor.summands[j]))
            #     error("NaN in sum factor backward pass $i $j")
            # end
        end
    end
end
