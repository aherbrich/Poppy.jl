using Printf
using Plots

function ranking_update!(urgencies::Dict{UInt64, Gaussian}, boards::AbstractArray; mask_in_prior::Int=2, beta::Float64=1.0, loop_eps::Float64=0.1)    
    # BLOCK 1
    feature_set = Set{UInt64}()
    for board in boards
        for feature in board
            if !haskey(urgencies, feature)
                urgencies[feature] = GaussianByMeanVariance(0.0, 1.0 / length(board))
            end
            push!(feature_set, feature)
        end
    end

    mask_prior = min(1.0, mask_in_prior / length(feature_set))

    mask_values = Dict{UInt64, Binary}()
    masked_features = Dict{UInt64, Gaussian}()
    gated_copy_factors = Vector{BinaryGatedCopyFactor}()

    for feature in feature_set
        mask_values[feature] = BinaryByProbability(mask_prior)
        masked_features[feature] = GaussianUniform()
        push!(gated_copy_factors, BinaryGatedCopyFactor(urgencies[feature], masked_features[feature], mask_values[feature]))
    end

    
    # BLOCK 3
    board_values = Vector{Gaussian}()
    sum_factors = Vector{SumFactor}()

    noisy_board_values = Vector{Gaussian}()
    latent_factors = Vector{GaussianMeanFactor}()

    for (k, _) in enumerate(boards)
        summands = Vector{Gaussian}()
        for feature in boards[k]
            push!(summands, masked_features[feature])
        end

        board_value = GaussianUniform()
        push!(board_values, board_value)
        push!(sum_factors, SumFactor(summands, board_value))

        noisy_board_value = GaussianUniform()
        push!(noisy_board_values, noisy_board_value)
        push!(latent_factors, GaussianMeanFactor(board_value, noisy_board_value, beta^2))
    end

    # BLOCK 4
    diff_values = Vector{Gaussian}()
    diff_factors = Vector{DifferenceFactor}()
    greater_than_factors = Vector{GreaterThanFactor}()

    for i in 2:length(boards)
        diff_value = GaussianUniform()
        push!(diff_values, diff_value)
        push!(diff_factors, DifferenceFactor(noisy_board_values[1], noisy_board_values[i], diff_value))
        push!(greater_than_factors, GreaterThanFactor(diff_value))
    end

    #############################################
    # SUM PRODUCT ALGORITHM

    # FOWARD-PASS: GATED COPY FACTORS
    for factor in gated_copy_factors
        update_msg_to_y!(factor)
    end

    # FORWARD-PASS: SUM NODES
    for factor in sum_factors
        update_msg_to_sum!(factor)
    end

    # FORWARD-PASS: LATENT NODES
    for factor in latent_factors
        update_msg_to_y!(factor)
    end

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

    # BACKWARD-PASS: LATENT NODES
    for factor in latent_factors
        update_msg_to_x!(factor)
    end

    # BACKWARD-PASS: SUM NODES
    for factor in sum_factors
        update_msg_to_summands!(factor)
    end


    # BACKWARD-PASS: GATED NODES
    for factor in gated_copy_factors
        update_msg_to_s!(factor)
        update_msg_to_x!(factor)
    end

end

# function ranking_update!(urgencies::Dict{UInt64, Gaussian}, boards::AbstractArray; mask_in_prior::Int=2, beta::Float64=1.0, loop_eps::Float64=0.1)
#     # BLOCK 1
#     feature_set = Set{UInt64}()
#     for board in boards
#         for feature in board
#             if !haskey(urgencies, feature)
#                 urgencies[feature] = GaussianByMeanVariance(0.0, 1.0)
#             end
#             push!(feature_set, feature)
#         end
#     end

#     mask_prior = mask_in_prior / length(feature_set)

#     mask_values = Dict{UInt64, Binary}()
#     for feature in feature_set
#         mask_values[feature] = BinaryByProbability(mask_prior)
#     end

    

#     # BLOCK 2
#     latent_values_of_all_boards = Vector{Vector{Gaussian}}()
#     latent_factors_of_all_boards = Vector{Vector{GaussianMeanFactor}}()

#     gated_values_of_all_boards = Vector{Vector{Gaussian}}()
#     gated_factors_of_all_boards = Vector{Vector{BinaryGatedCopyFactor}}()

#     for board in boards
#         latent_values = Vector{Gaussian}()
#         latent_factors = Vector{GaussianMeanFactor}()
        
#         gated_values = Vector{Gaussian}()
#         gated_factors = Vector{BinaryGatedCopyFactor}()

#         for feature in board
#             latent_value = GaussianUniform()
#             push!(latent_values, latent_value)
#             push!(latent_factors, GaussianMeanFactor(urgencies[feature], latent_value, beta^2))
            
#             gated_value = GaussianUniform()
#             push!(gated_values, gated_value)
#             push!(gated_factors, BinaryGatedCopyFactor(latent_value, gated_value, mask_values[feature]))
#         end

#         push!(latent_values_of_all_boards, latent_values)
#         push!(latent_factors_of_all_boards, latent_factors)

#         push!(gated_values_of_all_boards, gated_values)
#         push!(gated_factors_of_all_boards, gated_factors)
#     end

#     # BLOCK 3
#     board_values = Vector{Gaussian}()
#     sum_factors = Vector{SumFactor}()

#     for (k, _) in enumerate(boards)
#         gated_values = gated_values_of_all_boards[k]
#         summands = Vector{Gaussian}()
#         for gated_value in gated_values
#             push!(summands, gated_value)
#         end

#         board_value = GaussianUniform()
#         push!(board_values, board_value)
#         push!(sum_factors, SumFactor(summands, board_value))
#     end

#     # BLOCK 4
#     diff_values = Vector{Gaussian}()
#     diff_factors = Vector{DifferenceFactor}()
#     greater_than_factors = Vector{GreaterThanFactor}()

#     for i in 2:length(boards)
#         diff_value = GaussianUniform()
#         push!(diff_values, diff_value)
#         push!(diff_factors, DifferenceFactor(board_values[1], board_values[i], diff_value))
#         push!(greater_than_factors, GreaterThanFactor(diff_value))
#     end

#     #############################################
#     # SUM PRODUCT ALGORITHM

#     # Variables for plotting
#     overall_negative_variance_loop_count = 0
#     mask_values_over_time = Dict{UInt64, Vector{Float64}}()
#     plt = plot(legend=:topright, xlabel="Time", ylabel="Mask Value", title="Mask Values over Time", ylims=(0.0, 1.0))
    
#     # ACTUAL APPROXIMATE SUM PRODUCT ALGORITHM
#     outer_ϵ = 10 * loop_eps
#     outer_count = 0
#     while outer_ϵ > loop_eps
#         outer_ϵ = 0.0
#         outer_count += 1
#         println("Outer iteration: ", outer_count)

#         # FOWARD-PASS: LATENT NODES
#         for (i, factors) in enumerate(latent_factors_of_all_boards)
#             for factor in factors
#                 update_msg_to_y!(factor)
#             end
#         end

        
#         sum_factors_copy = deepcopy(sum_factors)
#         diff_factors_copy = deepcopy(diff_factors)
#         greater_than_factors_copy = deepcopy(greater_than_factors)
#         gated_factors_of_all_boards_copy = deepcopy(gated_factors_of_all_boards)

#         negative_variance_loop_count = 0
#         while true
#             negative_variance_loop_count += 1  
#             overall_negative_variance_loop_count += 1  

#             # FORWARD-PASS: GATED NODES
#             for (i, factors) in enumerate(gated_factors_of_all_boards)
#                 for (j, factor) in enumerate(factors)
#                     update_msg_to_y!(factor)
#                 end
#             end
            
#             # FORWARD-PASS: SUM NODES
#             for (i, factor) in enumerate(sum_factors)
#                 update_msg_to_sum!(factor)
#             end

#             # RUN UNTIL LOOP CONVERGES
#             ϵ = 10 * loop_eps
#             while ϵ > loop_eps
#                 ϵ = 0.0
#                 for (i, factor) in enumerate(diff_factors)
#                     ϵ = max(ϵ, update_msg_to_z!(factor))
#                     ϵ = max(ϵ, update_msg_to_x!(greater_than_factors[i]))
#                     ϵ = max(ϵ, update_msg_to_x!(factor))
#                     ϵ = max(ϵ, update_msg_to_y!(factor))
#                 end
#             end

#             # BACKWARD-PASS: SUM NODES
#             for factor in sum_factors
#                 update_msg_to_summands!(factor)
#             end


#             # BACKWARD-PASS: GATED NODES
#             negative_variance = false
#             for (i, factors) in enumerate(gated_factors_of_all_boards)
#                 for (j, factor) in enumerate(factors)
#                     update_msg_to_x!(factor)
#                     if variance(factor.msg_to_x) < 0.0 || variance(factor.msg_to_y) < 0.0
#                         negative_variance = true
#                     end
                    
#                     update_msg_to_s!(factor)
#                     if mean(factor.s) < 1e-4
#                         update!(factor.s, BinaryByProbability(0.0))
#                     elseif mean(factor.s) > 1.0 - 1e-4
#                         update!(factor.s, BinaryByProbability(1.0))
#                     end
#                 end
#             end


#             if !negative_variance
#                 break
#             end

#             if negative_variance_loop_count > 100
#                 error("Should not reach here")
#             end

#             if negative_variance_loop_count == 100
#                 for (i, factors) in enumerate(gated_factors_of_all_boards)
#                     for (j, factor) in enumerate(factors)
#                         if variance(factor.msg_to_x) < 0.0 || variance(factor.msg_to_y) < 0.0
#                             update!(factor.s, BinaryByProbability(1.0))
#                         end
#                     end
#                 end
#             end

#             # RESET FACTORS
#             for (sum_factor, sum_factor_copy) in zip(sum_factors, sum_factors_copy)
#                 update!(sum_factor, sum_factor_copy)
#             end

#             for (diff_factor, diff_factor_copy) in zip(diff_factors, diff_factors_copy)
#                 update!(diff_factor, diff_factor_copy)
#             end

#             for (greater_than_factor, greater_than_factor_copy) in zip(greater_than_factors, greater_than_factors_copy)
#                 update!(greater_than_factor, greater_than_factor_copy)
#             end

#             for (gated_factors_of_all_boards, gated_factors_of_all_boards_copy) in zip(gated_factors_of_all_boards, gated_factors_of_all_boards_copy)
#                 for (factor, factor_copy) in zip(gated_factors_of_all_boards, gated_factors_of_all_boards_copy)
#                     update!(factor, factor_copy; exclude_s=true)
#                 end
#             end

#             for (key, value) in mask_values
#                 if haskey(mask_values_over_time, key)
#                     push!(mask_values_over_time[key], mean(value))
#                 else
#                     mask_values_over_time[key] = [mean(value)]
#                 end
#             end
#         end
#         println("Looped $negative_variance_loop_count times, to eliminate negative variances")
        
#         # PLOT MASK VALUES
#         vline!(plt, [outer_count], label="Outer iteration $outer_count", color=:black)
#         if outer_count == 3
#             for (key, value) in mask_values_over_time
#                 plot!(plt, value, label="Feature $key", lw=rand(1:5), alpha=0.5)
#             end
#             display(plt)
#         end

#         # BACKWARD-PASS: LATENT NODES
#         for (i, factors) in enumerate(latent_factors_of_all_boards)
#             for factor in factors
#                 outer_ϵ = max(outer_ϵ, update_msg_to_x!(factor))
#             end
#         end

#         println("\033[91;1mAfter outer iteration: $outer_count, outer_ϵ: $outer_ϵ\033[0m")              
#     end
# end

function ranking_update_by_sampling!(urgencies::Dict{UInt64, Gaussian}, boards::AbstractArray; mask_in_prior::Int=2, beta::Float64=1.0, no_samples::Int=100000, logging::Bool=false)
    feature_set = Set{UInt64}()
    for board in boards
        println(convert(Vector{Int}, board.hashes))
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
    # no_sample many times -> for every feature -> masked feature
    masked_urgencies_samples = Vector{Dict{UInt64, Float64}}(undef, no_samples)

    # no_sample many times -> for every board -> sum of all masked latent urgencies
    values_samples = Vector{Vector{Float64}}(undef, no_samples)

    for i in 1:no_samples
        urgencies_sample = Dict{UInt64, Float64}()
        mask_sample = Dict{UInt64, Float64}()
        masked_urgencies_sample = Dict{UInt64, Float64}()
        for feature in feature_set
            urgencies_sample[feature] = rand(Normal(mean(urgencies[feature]), sqrt(variance(urgencies[feature]))))
            mask_sample[feature] = (rand(Bernoulli(mask_prior)) == true) ? 1.0 : 0.0
            masked_urgencies_sample[feature] = urgencies_sample[feature] * mask_sample[feature]
        end
        urgencies_samples[i] = urgencies_sample
        mask_samples[i] = mask_sample
        masked_urgencies_samples[i] = masked_urgencies_sample

        values_all_boards = Vector{Float64}(undef, length(boards))

        for (k, board) in enumerate(boards)
            value = 0.0

            for feature in board
                value += masked_urgencies_sample[feature]
            end

            values_all_boards[k] = rand(Normal(value, beta))
        end

        values_samples[i] = values_all_boards
    end

    ############################################################################################################
    # PRINT THE RESULTS & UPDATE THE MODEL
    ############################################################################################################

    # PRIOR & POSTERIOR FOR URGENCY MASK
    if logging
        println("Mask\t\tPrior\t\tPosterior")
        for feature in sort!(collect(feature_set))
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
    for feature in sort!(collect(feature_set))
        

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