using Printf

function ranking_update!(urgencies::Dict{UInt64, Gaussian}, boards::AbstractArray; mask_in_prior::Int=2, beta::Float64=1.0, loop_eps::Float64=0.1)
    # BLOCK 1
    feature_set = Set{UInt64}()
    for board in boards
        for feature in board
            if !haskey(urgencies, feature)
                urgencies[feature] = GaussianByMeanVariance(0.0, 1.0)
            end
            push!(feature_set, feature)
        end
    end

    mask_prior = mask_in_prior / length(feature_set)

    mask_values = Dict{UInt64, Binary}()
    for feature in feature_set
        mask_values[feature] = BinaryByProbability(mask_prior)
    end

    

    # BLOCK 2
    latent_values_of_all_boards = Vector{Vector{Gaussian}}()
    latent_factors_of_all_boards = Vector{Vector{GaussianMeanFactor}}()

    gated_values_of_all_boards = Vector{Vector{Gaussian}}()
    gated_factors_of_all_boards = Vector{Vector{BinaryGatedCopyFactor}}()

    for board in boards
        latent_values = Vector{Gaussian}()
        latent_factors = Vector{GaussianMeanFactor}()
        
        gated_values = Vector{Gaussian}()
        gated_factors = Vector{BinaryGatedCopyFactor}()

        for feature in board
            latent_value = GaussianUniform()
            push!(latent_values, latent_value)
            push!(latent_factors, GaussianMeanFactor(urgencies[feature], latent_value, beta^2))
            
            gated_value = GaussianUniform()
            push!(gated_values, gated_value)
            push!(gated_factors, BinaryGatedCopyFactor(latent_value, gated_value, mask_values[feature]))
        end

        push!(latent_values_of_all_boards, latent_values)
        push!(latent_factors_of_all_boards, latent_factors)

        push!(gated_values_of_all_boards, gated_values)
        push!(gated_factors_of_all_boards, gated_factors)
    end

    # BLOCK 3
    board_values = Vector{Gaussian}()
    sum_factors = Vector{SumFactor}()

    for (k, _) in enumerate(boards)
        gated_values = gated_values_of_all_boards[k]
        summands = Vector{Gaussian}()
        for gated_value in gated_values
            push!(summands, gated_value)
        end

        board_value = GaussianUniform()
        push!(board_values, board_value)
        push!(sum_factors, SumFactor(summands, board_value))
    end

    # BLOCK 4
    diff_values = Vector{Gaussian}()
    diff_factors = Vector{DifferenceFactor}()
    greater_than_factors = Vector{GreaterThanFactor}()

    for i in 2:length(boards)
        diff_value = GaussianUniform()
        push!(diff_values, diff_value)
        push!(diff_factors, DifferenceFactor(board_values[1], board_values[i], diff_value))
        push!(greater_than_factors, GreaterThanFactor(diff_value))
    end

    #############################################
    # SUM PRODUCT ALGORITHM

    outer_ϵ = 10 * loop_eps
    outer_count = 0
    while outer_ϵ > loop_eps
        outer_ϵ = 0.0
        outer_count += 1
        println("Outer iteration: ", outer_count)

        # FOWARD-PASS: LATENT NODES
        for (i, factors) in enumerate(latent_factors_of_all_boards)
            for factor in factors
                update_msg_to_y!(factor)
            end
        end

        println("test 1")

        # for factor in sum_factors
        #     for i in eachindex(factor.summands)
        #         if factor.summands[i].ρ - factor.msg_to_summands[i].ρ < 0.0
        #             error("After latent nodes update!")
        #         end
        #     end
        # end

        # FORWARD-PASS: GATED NODES
        for (i, factors) in enumerate(gated_factors_of_all_boards)
            for (j, factor) in enumerate(factors)
                # if factor.msg_to_y != (sum_factors[i].summands[j] / sum_factors[i].msg_to_summands[j])
                #     error("Gated nodes BEFORE update 1!")
                # end
                
                # if sum_factors[i].msg_to_summands[j] != (factor.y / factor.msg_to_y)
                #     error("Gated nodes BEFORE update 2!")
                # end


                update_msg_to_y!(factor)

                # if factor.msg_to_y != (sum_factors[i].summands[j] / sum_factors[i].msg_to_summands[j])
                #     println(factor.msg_to_y)
                #     println((sum_factors[i].summands[j] / sum_factors[i].msg_to_summands[j]))
                #     println(factor)
                #     println(sum_factors[i])
                #     error("Gated nodes update 1!")
                # end
                
                # if sum_factors[i].msg_to_summands[j] != (factor.y / factor.msg_to_y)
                #     println(sum_factors[i].msg_to_summands[j])                    
                #     println((factor.y / factor.msg_to_y))
                #     println()
                #     println(factor.msg_to_y)
                #     println(sum_factors[i].msg_to_summands[j])
                #     println(factor.y)
                #     println((sum_factors[i].summands[j] / sum_factors[i].msg_to_summands[j]))
                #     println(factor)
                #     println(sum_factors[i])
                #     error("Gated nodes update 2!")
                # end

            end
        end

        println("test 2")

        # for factor in sum_factors
        #     for i in eachindex(factor.summands)
        #         if factor.summands[i].ρ - factor.msg_to_summands[i].ρ < 0.0
        #             error("After gated nodes update!")
        #         end
        #     end
        # end
        

        # FORWARD-PASS: SUM NODES
        for (i, factor) in enumerate(sum_factors)
            update_msg_to_sum!(factor)
        end

        println("test 3")

        # for factor in sum_factors
        #     for i in eachindex(factor.summands)
        #         if factor.summands[i].ρ - factor.msg_to_summands[i].ρ < 0.0
        #             error("After sum nodes update!")
        #         end
        #     end
        # end

        

        # RUN UNTIL LOOP CONVERGES
        ϵ = 10 * loop_eps
        while ϵ > loop_eps
            ϵ = 0.0
            for (i, factor) in enumerate(diff_factors)
                ϵ = max(ϵ, update_msg_to_z!(factor))
                ϵ = max(ϵ, update_msg_to_x!(greater_than_factors[i]))
                ϵ = max(ϵ, update_msg_to_x!(factor))
                ϵ = max(ϵ, update_msg_to_y!(factor))
            end
        end

        println("test 4")

        # for factor in sum_factors
        #     for i in eachindex(factor.summands)
        #         if factor.summands[i].ρ - factor.msg_to_summands[i].ρ < 0.0
        #             error("After diff nodes update!")
        #         end
        #     end
        # end

        # BACKWARD-PASS: SUM NODES
        for factor in sum_factors
            update_msg_to_summands!(factor)
        end

        println("test 5")

        # for factor in sum_factors
        #     for i in eachindex(factor.summands)
        #         if factor.summands[i].ρ - factor.msg_to_summands[i].ρ < 0.0
        #             error("After sum nodes backward update!")
        #         end
        #     end
        # end

        # BACKWARD-PASS: GATED NODES
        for (i, factors) in enumerate(gated_factors_of_all_boards)
            for (j, factor) in enumerate(factors)
                update_msg_to_x!(factor)
                update_msg_to_s!(factor)
            end
        end

        # for factor in sum_factors
        #     for i in eachindex(factor.summands)
        #         if factor.summands[i].ρ - factor.msg_to_summands[i].ρ < 0.0
        #             error("After gated nodes backward update!")
        #         end
        #     end
        # end

        # BACKWARD-PASS: LATENT NODES
        for (i, factors) in enumerate(latent_factors_of_all_boards)
            for factor in factors
                outer_ϵ = max(outer_ϵ, update_msg_to_x!(factor))
            end
        end

        # for factor in sum_factors
        #     for i in eachindex(factor.summands)
        #         if factor.summands[i].ρ - factor.msg_to_summands[i].ρ < 0.0
        #             @error("After latent nodes backward update!")
        #         end
        #     end
        # end

        println("outer_ϵ: ", outer_ϵ)
    end

    # BACKWARD-PASS: GATED NODES
    # for (i, factors) in enumerate(gated_factors_of_all_boards)
    #     for factor in factors
    #         update_msg_to_s!(factor)
    #     end
    # end

    # for feature in feature_set
    #     println("Feature $feature: ", mask_values[feature])
    # end

end

function ranking_update_by_sampling!(urgencies::Dict{UInt64, Gaussian}, boards::AbstractArray; mask_in_prior::Int=2, beta::Float64=1.0, no_samples::Int=100000, logging::Bool=false)
    feature_set = Set{UInt64}()
    for board in boards
        for feature in board
            if !haskey(urgencies, feature)
                urgencies[feature] = Gaussian(0.0, 1.0)
            end

            push!(feature_set, feature)
        end
    end

    mask_prior = mask_in_prior / length(feature_set)

    # no_sample many times -> for every feature -> sample urgency
    urgencies_samples = Vector{Dict{UInt64, Float64}}(undef, no_samples)
    # no_sample many times -> for every feature -> sample mask (0/1) for urgency
    mask_samples = Vector{Dict{UInt64, Float64}}(undef, no_samples)

    # no_sample many times -> for every board -> for every feature -> sample latent urgency
    latent_urgencies_samples = Vector{Vector{Dict{UInt64, Float64}}}(undef, no_samples)
    # no_sample many times -> for every board -> for every feature -> mask out/in latent urgencies with mask
    masked_urgencies_samples = Vector{Vector{Dict{UInt64, Float64}}}(undef, no_samples)
    # no_sample many times -> for every board -> sum of all masked latent urgencies
    values_samples = Vector{Vector{Float64}}(undef, no_samples)

    for i in 1:no_samples
        urgencies_sample = Dict{UInt64, Float64}()
        mask_sample = Dict{UInt64, Float64}()
        for feature in feature_set
            urgencies_sample[feature] = rand(Normal(gmean(urgencies[feature]), sqrt(variance(urgencies[feature]))))
            mask_sample[feature] = (rand(Bernoulli(mask_prior)) == true) ? 1.0 : 0.0
        end
        urgencies_samples[i] = urgencies_sample
        mask_samples[i] = mask_sample

        latent_urgencies_all_boards = Vector{Dict{UInt64, Float64}}(undef, length(boards))
        masked_urgencies_all_boards = Vector{Dict{UInt64, Float64}}(undef, length(boards))
        values_all_boards = Vector{Float64}(undef, length(boards))

        for (k, board) in enumerate(boards)
            latent_urgencies = Dict{UInt64, Float64}()
            masked_urgencies = Dict{UInt64, Float64}()
            value = 0.0

            for feature in board
                latent_urgencies[feature] = rand(Normal(urgencies_sample[feature], beta))
                masked_urgencies[feature] = latent_urgencies[feature] * mask_sample[feature]
                value += masked_urgencies[feature]
            end

            latent_urgencies_all_boards[k] = latent_urgencies
            masked_urgencies_all_boards[k] = masked_urgencies
            values_all_boards[k] = value
        end

        latent_urgencies_samples[i] = latent_urgencies_all_boards
        masked_urgencies_samples[i] = masked_urgencies_all_boards
        values_samples[i] = values_all_boards
    end

    ############################################################################################################
    # PRINT THE RESULTS & UPDATE THE MODEL
    ############################################################################################################

    # PRIOR & POSTERIOR FOR URGENCY MASK
    if logging
        println("Mask\t\tPrior\t\tPosterior")
        for feature in feature_set
            print("$feature\t\t")

            # calculate the prior & posterior
            μ_prior = 0.0
            μ2_prior = 0.0
            μ_posterior = 0.0
            μ2_posterior = 0.0
            posterior_count = 0
            for i in 1:no_samples
                μ_prior += mask_samples[i][feature]
                μ2_prior += mask_samples[i][feature]^2

                if count(x -> x >= values_samples[i][1], values_samples[i]) == 1
                    μ_posterior += mask_samples[i][feature]
                    μ2_posterior += mask_samples[i][feature]^2
                    posterior_count += 1
                end
            end
            μ_prior /= no_samples
            μ2_prior /= no_samples
            σ_prior = sqrt(μ2_prior - μ_prior^2)

            μ_posterior /= posterior_count
            μ2_posterior /= posterior_count
            σ_posterior = sqrt(μ2_posterior - μ_posterior^2)

            (μ_prior > 0.0) ? @printf("+%.3f ± %.3f\t" , μ_prior, σ_prior) : @printf("%.3f ± %.3f\t" , μ_prior, σ_prior)
            (μ_posterior > 0.0) ? @printf("+%.3f ± %.3f\n" , μ_posterior, σ_posterior) : @printf("%.3f ± %.3f\n" , μ_posterior, σ_posterior)
        end
    end

    # PRIOR & POSTERIOR FOR URGENCY
    logging && println("Urgency\t\tPrior\t\tPosterior")
    for feature in feature_set
        

        # calculate the prior
        μ_prior = 0.0
        μ2_prior = 0.0
        μ_posterior = 0.0
        μ2_posterior = 0.0
        posterior_count = 0
        for i in 1:no_samples
            μ_prior += urgencies_samples[i][feature]
            μ2_prior += urgencies_samples[i][feature]^2

            if count(x -> x >= values_samples[i][1], values_samples[i]) == 1
                μ_posterior += urgencies_samples[i][feature]
                μ2_posterior += urgencies_samples[i][feature]^2
                posterior_count += 1
            end
        end
        μ_prior /= no_samples
        μ2_prior /= no_samples
        σ_prior = sqrt(μ2_prior - μ_prior^2)

        μ_posterior /= posterior_count
        μ2_posterior /= posterior_count
        σ_posterior = sqrt(μ2_posterior - μ_posterior^2)

        if logging
            print("$feature\t\t")
            (μ_prior > 0.0) ? @printf("+%.2f ± %.2f\t" , μ_prior, σ_prior) : @printf("%.2f ± %.2f\t" , μ_prior, σ_prior)
            (μ_posterior > 0.0) ? @printf("+%.2f ± %.2f\n" , μ_posterior, σ_posterior) : @printf("%.2f ± %.2f\n" , μ_posterior, σ_posterior)
        end

        # UPDATE 
        urgencies[feature] = GaussianByMeanVariance(μ_posterior, σ_posterior)
    end
end