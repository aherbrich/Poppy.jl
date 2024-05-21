struct Graph
    urgencies::Dict{Int, Gaussian}
    gaussian_factors::Vector{GaussianFactor}
    latent_urgencies::Vector{Vector{Gaussian}}
    gaussian_mean_factors::Vector{Vector{GaussianMeanFactor}}
    diffs::Vector{Vector{Gaussian}}
    weighted_sum_factors::Vector{Vector{WeightedSumFactor}}
    greather_than_factors::Vector{Vector{GreaterThanFactor}}
end

function Graph()
    urgencies = Dict{Int, Gaussian}()
    gaussian_factors = Vector{GaussianFactor}()
    latent_urgencies = Vector{Vector{Gaussian}}()
    gaussian_mean_factors = Vector{Vector{GaussianMeanFactor}}()
    diffs = Vector{Vector{Gaussian}}()
    weighted_sum_factors = Vector{Vector{WeightedSumFactor}}()
    greather_than_factors = Vector{Vector{GreaterThanFactor}}()

    return Graph(urgencies, gaussian_factors, latent_urgencies, gaussian_mean_factors, diffs, weighted_sum_factors, greather_than_factors)
end

function print_gaussian(urgencies)
    for urgency in urgencies
        println(urgency)
    end
end


function add_ranking_problem!(graph::Graph, moves)
    for move in moves
        if !haskey(graph.urgencies, move)
            graph.urgencies[move] = GaussianUniform()
            push!(graph.gaussian_factors, GaussianFactor(graph.urgencies[move], GaussianByMeanVariance(0.0, 1.0)))
        end
    end

    latent_urgencies = Vector{Gaussian}()
    gaussian_mean_factors = Vector{GaussianMeanFactor}()

    for move in moves
        latent_urgency = GaussianUniform()
        push!(latent_urgencies, latent_urgency)
        push!(gaussian_mean_factors, GaussianMeanFactor(latent_urgency, graph.urgencies[move], 0.5))
    end

    diffs = Vector{Gaussian}()
    weighted_sum_factors = Vector{WeightedSumFactor}()
    greather_than_factors = Vector{GreaterThanFactor}()

    for i in 2:length(latent_urgencies)
        diff = GaussianUniform()
        push!(diffs, diff)
        push!(weighted_sum_factors, WeightedSumFactor(latent_urgencies[1], latent_urgencies[i], diff, 1.0, -1.0))
        push!(greather_than_factors, GreaterThanFactor(diff))
    end

    push!(graph.latent_urgencies, latent_urgencies)
    push!(graph.gaussian_mean_factors, gaussian_mean_factors)
    push!(graph.diffs, diffs)
    push!(graph.weighted_sum_factors, weighted_sum_factors)
    push!(graph.greather_than_factors, greather_than_factors)
end

function rank(graph::Graph; outer_eps=1e-1, inner_eps=1e-3)    
    #############################################
    # SUM PRODUCT ALGORITHM

    # INITIALIZE URGENCIES WITH PRIOR
    for factor in graph.gaussian_factors
        update_msg_to_x!(factor)
    end

    # RUN UNTIL ALL URGENCIES CONVERGE
    eps_outer = 10 * outer_eps
    while eps_outer > outer_eps
        eps_outer = 0.0
        nr_games = length(graph.gaussian_mean_factors)

        # LOOP THROUGH ALL GAME SUBGRAPHS
        for i in 1:nr_games
            for factor in graph.gaussian_mean_factors[i]
                update_msg_to_x!(factor)
            end

    
            # RUN UNTIL LOOP CONVERGES
            eps_inner = 10*inner_eps
            while eps_inner > inner_eps
                eps_inner = 0.0
                for (j, factor) in enumerate(graph.weighted_sum_factors[i])
                    eps_inner = max(eps_inner, update_msg_to_z!(factor))
                    eps_inner = max(eps_inner, update_msg_to_x!(graph.greather_than_factors[i][j]))
                    eps_inner = max(eps_inner, update_msg_to_x!(factor))
                end
            end

            # SEND BACK MESSAGES
            for factor in graph.weighted_sum_factors[i]
                update_msg_to_y!(factor)
            end

            # UPDATE URGENCIES
            for factor in graph.gaussian_mean_factors[i]
                eps_outer = max(eps_outer, update_msg_to_y!(factor))
            end
        end

        println(stderr, "Outer eps: ", eps_outer)
    end

    return graph.urgencies
end

function ranking_update!(urgencies::Dict{UInt64, Gaussian}, moves; loop_eps=1e-3)
    # INITIALIZE (UNSEEN) PATTERNS WITH STANDARD NORMAL URGENCIES
    for move in moves
        if !haskey(urgencies, move)
            urgencies[move] = GaussianUniform()
            update_msg_to_x!(GaussianFactor(urgencies[move], GaussianByMeanVariance(0.0, 1.0)))
        end
    end

    # INITIALIZE ALL OTHER VARIABLES AND FACTORS
    latent_urgencies = Vector{Gaussian}()
    gaussian_mean_factors = Vector{GaussianMeanFactor}()

    for move in moves
        latent_urgency = GaussianUniform()
        push!(latent_urgencies, latent_urgency)
        push!(gaussian_mean_factors, GaussianMeanFactor(latent_urgency, urgencies[move], 0.5))
    end

    diffs = Vector{Gaussian}()
    weighted_sum_factors = Vector{WeightedSumFactor}()
    greather_than_factors = Vector{GreaterThanFactor}()

    for i in 2:length(latent_urgencies)
        diff = GaussianUniform()
        push!(diffs, diff)
        push!(weighted_sum_factors, WeightedSumFactor(latent_urgencies[1], latent_urgencies[i], diff, 1.0, -1.0))
        push!(greather_than_factors, GreaterThanFactor(diff))
    end

    #############################################
    # SUM PRODUCT ALGORITHM

    # LATENT URGENCIES
    for factor in gaussian_mean_factors
        update_msg_to_x!(factor)
    end

    # RUN UNTIL LOOP CONVERGES
    ϵ = 10 * loop_eps
    while ϵ > loop_eps
        ϵ = 0.0
        for (i, factor) in enumerate(weighted_sum_factors)
            ϵ = max(ϵ, update_msg_to_z!(factor))
            ϵ = max(ϵ, update_msg_to_x!(greather_than_factors[i]))
            ϵ = max(ϵ, update_msg_to_x!(factor))
        end
    end

    # SEND BACK MESSAGES
    for factor in weighted_sum_factors
        update_msg_to_y!(factor)
    end

    # UPDATE URGENCIES
    for factor in gaussian_mean_factors
        ϵ = max(ϵ, update_msg_to_y!(factor))
    end
end

