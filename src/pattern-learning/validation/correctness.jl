using Distributions
using StatsBase
using Random

# Random.seed!(ceil(Int, time()))

function test_correctness_simple()
    # FEATURES
    feature_values = [-1.0, 2.0]
    beta = 1.0

    sampled_games = Vector{Vector{Vector{UInt64}}}()
    N = 100000

    for _ in 1:N
        competing_feature_sets = [[UInt64(1)], [UInt64(2)]]
        

        # SAMPLE VALUES FOR COMPETING FEATURE SETS & SORT THEM BY SAMPLED VALUES
        sampled_values = [
            rand(Normal(sum(feature_values[competing_feature_sets[1]]), beta)),
            rand(Normal(sum(feature_values[competing_feature_sets[2]]), beta))
        ]
        competing_feature_sets = competing_feature_sets[sortperm(sampled_values, rev=true)]

        push!(sampled_games, competing_feature_sets)
    end

    
    # TRAIN MODEL ON SAMPLE DATA

    model = ValueTable(no_bits = 24)

    for competing_feature_sets in sampled_games
        ranking_update!(model, competing_feature_sets, beta=beta)
    end

    for (key, value) in model
        println("$(key) -> $(value)")
    end
end

function test_correctness_complex()
    # FEATURES
    feature_values = [3.0, -1.0, -1.0, 1.0, 1.5]
    beta = 1.0

    sampled_games = Vector{Vector{Vector{UInt64}}}()
    N = 100000
    

    for _ in 1:N
        # GENERATE RANDOM COMPETING FEATURE SETS
        competing_feature_sets = Vector{Vector{UInt64}}()
        for i in 1:rand(2:5)
            feature_set = sample(UInt64(1):UInt64(5), rand(2:5), replace=false)
            while any(issetequal(feature_set, competing_feature_set) for competing_feature_set in competing_feature_sets)
                feature_set = sample(UInt64(1):UInt64(5), rand(2:5), replace=false)
            end
            push!(competing_feature_sets, feature_set)
        end

        # SAMPLE VALUES FOR COMPETING FEATURE SETS & SORT THEM BY SAMPLED VALUES
        sampled_values = [
            rand(Normal(sum(feature_values[feature_set]), beta)) for feature_set in competing_feature_sets 
        ]
        competing_feature_sets = competing_feature_sets[sortperm(sampled_values, rev=true)]

        push!(sampled_games, competing_feature_sets)
    end


    # TRAIN MODEL ON SAMPLE DATA

    model = ValueTable(no_bits = 24)

    for competing_feature_sets in sampled_games
        ranking_update!(model, competing_feature_sets, beta=beta)
    end

    for (key, value) in model
        println("$(key) -> $(value)")
    end
end

function test_greater_than(N = 10000)
    x = GaussianUniform()

    prior = GaussianFactor(x, GaussianByMeanVariance(0.0, 1.0))
    update_msg_to_x!(prior)

    println(x)
    μ = 1.0
    for i = 1:N
        latent = rand(Normal(μ, 1.0))
        if (latent > 0.0)
            print("+ ")
            data_factor = GreaterThanFactor(x)
            update_msg_to_x!(data_factor)
        else
            print("- ")
            t = GaussianByMeanVariance(0.0, 1e-18)
            minus_x = GaussianUniform()
            diff_factor = DifferenceFactor(t, x, minus_x)
            data_factor = GreaterThanFactor(minus_x)
            update_msg_to_z!(diff_factor)
            update_msg_to_x!(data_factor)
            update_msg_to_y!(diff_factor)
        end
        println(x)
    end
    println(x)
end