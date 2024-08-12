using Distributions
using Plots
using StatsBase

function test_sign_consistency_factor(mu::Float64, sigma::Float64, p::Float64)
    no_samples = 10000000
    normal = Normal(mu, sigma)

    samples = rand(normal, no_samples)
    weighting = Vector{Float64}(undef, no_samples)
    
    for i in 1:no_samples
        if samples[i] > 0.0
            weighting[i] = p
        else
            weighting[i] = 1.0 - p
        end
    end

    μ = sum(samples.*weighting) / sum(weighting)
    σ = sqrt(sum((samples .- μ).^2 .* weighting) / sum(weighting))


    c = cdf(Normal(0,1), -mu/sigma)
    d = pdf(Normal(0,1), -mu/sigma)
    normalization = (1-2*p) * c + p

    # theoretical_μ = (1/normalization) * ((1-p) * (   c  * mu - sigma * d) +
    #                                         p  * ((1-c) * mu + sigma * d)) 
    theoretical_μ = mu - (((1-2*p)*d*sigma) / ((1-2*p) * c + p))
    
    # Δ_1 = cdf(Normal(0,1), -mu/sigma)
    # Δ_2 = 1 - cdf(Normal(0,1), -mu/sigma)
    # second_moment = (1/normalization) * ((1-p) * (Δ_1 * (mu^2 + sigma^2) - sigma * (mu * d)) +
    #                                         p *  (Δ_2 * (mu^2 + sigma^2) + sigma * (mu * d)))
    # theoretical_σ = sqrt(second_moment - theoretical_μ^2)

    v = ((1-2*p) * d) / ((1-2*p) * c + p)
    theoretical_σ = sqrt(sigma^2 * (1-v*(v-(mu/sigma))))

    println("Theoretical μ: $(theoretical_μ)")
    println("Empirical μ: $μ")
    println("Theoretical σ: $(theoretical_σ)")
    println("Empirical σ: $σ")

    # function my_v(;p=0.5)
    #     return x -> ((1-2*p) * pdf(Normal(0,1), x)) / ((1-2*p) * cdf(Normal(0,1), x) + p)
    # end

    # plot(my_v(p=0), -5, 5, label="theoretical p=0", lw=3)
    # plot(my_v(p=0.1), -10, 10, label="theoretical p=0.1", lw=3)
    # plot!(my_v(p=0.25), -10, 10, label="theoretical p=0.25", lw=3)
    # plot!(my_v(p=0.5), -10, 10, label="theoretical p=0.5", lw=3)
    # plot!(my_v(p=0.75), -10, 10, label="theoretical p=0.75", lw=3)
    # plot!(my_v(p=0.9), -10, 10, label="theoretical p=0.9", lw=3)
    # plot!(my_v(p=1), -5, 5, label="theoretical p=1", lw=3)

    histogram(samples, weights=weighting, normalize=:pdf,label="sampled")
    plot!(f(theoretical_μ, theoretical_σ), color=:red, lw=3)
end

# test_sign_consistency_factor(-2.2, 1.0, 0.9)

function test_binary_gated_copy_factor(μ_x::Float64, σ_x::Float64, μ_y::Float64, σ_y::Float64, p::Float64)
    no_samples = 100000000

    normal_x = Normal(μ_x, σ_x)
    normal_y = Normal(μ_y, σ_y)
    bernoulli = Bernoulli(p)

    samples_of_x = rand(normal_x, no_samples)
    samples_of_y = rand(normal_y, no_samples)
    binary_samples = rand(bernoulli, no_samples)

    weighting = Vector{Float64}(undef, no_samples)

    dirac = Normal(0, 0.1)

    for i in 1:no_samples
        weighting[i] = pdf(dirac, samples_of_y[i] - samples_of_x[i] * binary_samples[i])
    end

    empirical_second_moment = sum((samples_of_y.^2) .* weighting) / sum(weighting)
    empirical_μ_y = sum(samples_of_y .* weighting) / sum(weighting)
    empirical_σ_y = sqrt(empirical_second_moment - empirical_μ_y^2)

    normalization = (1-p) * pdf(Normal(μ_y, σ_y), 0) +
                       p  * pdf(Normal(μ_y, sqrt(σ_y^2 + σ_x^2)), μ_x)

    μ_xy = ((μ_y * σ_x^2 + μ_x * σ_y^2) / (σ_x^2 + σ_y^2))
    σ2_xy = ((σ_x^2 * σ_y^2) / (σ_x^2 + σ_y^2))

    second_moment = (1/normalization) * p * pdf(Normal(μ_y, sqrt(σ_y^2 + σ_x^2)), μ_x) * (μ_xy^2 + σ2_xy)

    theoretical_μ = (1/normalization) * p * pdf(Normal(μ_y, sqrt(σ_y^2 + σ_x^2)), μ_x) * μ_xy
    theoretical_σ = sqrt(second_moment - theoretical_μ^2)



    println("theoretical_μ: $theoretical_μ")
    println("empirical_μ: $empirical_μ_y")
    println("theoretical_σ: $theoretical_σ")
    println("empirical_σ: $empirical_σ_y")

    histogram(samples_of_y, weights=weighting, normalize=:pdf, label="sampled")
    plot!(x->pdf(Normal(empirical_μ_y, empirical_σ_y), x), -10, 10, lw=4, color=:green, label="empirical")
    plot!(x->pdf(Normal(theoretical_μ, theoretical_σ), x), -10, 10, lw=2, color=:red, label="theoretical")
end

# test_binary_gated_copy_factor(2.0, 1.0, 3.0, 1.0, 0.1)

function test_binary_gated_copy_factor_2(μ_x::Float64, σ_x::Float64, μ_y::Float64, σ_y::Float64, p::Float64)
    no_samples = 100000000

    normal_x = Normal(μ_x, σ_x)
    normal_y = Normal(μ_y, σ_y)
    bernoulli = Bernoulli(p)

    samples_of_x = rand(normal_x, no_samples)
    samples_of_y = rand(normal_y, no_samples)
    binary_samples = rand(bernoulli, no_samples)

    weighting = Vector{Float64}(undef, no_samples)

    dirac = Normal(0, 0.01)

    for i in 1:no_samples
        weighting[i] = pdf(dirac, samples_of_y[i] - samples_of_x[i] * binary_samples[i])
    end

    empirical_second_moment = sum((samples_of_x.^2) .* weighting) / sum(weighting)
    empirical_μ_x = sum(samples_of_x .* weighting) / sum(weighting)
    empirical_σ_x = sqrt(empirical_second_moment - empirical_μ_x^2)

    normalization = (1-p) * pdf(Normal(μ_y, σ_y), 0) +
                       p  * pdf(Normal(μ_y, sqrt(σ_y^2 + σ_x^2)), μ_x)

    μ_xy = ((μ_y * σ_x^2 + μ_x * σ_y^2) / (σ_x^2 + σ_y^2))
    σ2_xy = ((σ_x^2 * σ_y^2) / (σ_x^2 + σ_y^2))

    second_moment = (1/normalization) * (
        (1-p) * pdf(Normal(μ_y, σ_y), 0) * (μ_x^2 + σ_x^2) +
        p  * pdf(Normal(μ_y, sqrt(σ_y^2 + σ_x^2)), μ_x) * (μ_xy^2 + σ2_xy)
    )

    theoretical_μ = (1/normalization) * ((1-p) * pdf(Normal(μ_y, σ_y), 0) * μ_x +
                                            p  * pdf(Normal(μ_y, sqrt(σ_y^2 + σ_x^2)), μ_x) * μ_xy)
    theoretical_σ = sqrt(second_moment - theoretical_μ^2)
    
    println("theoretical_μ_x: $theoretical_μ")
    println("empirical_μ_x: $empirical_μ_x")
    println("theoretical_σ_x: $theoretical_σ")
    println("empirical_σ_x: $empirical_σ_x")

    histogram(samples_of_x, weights=weighting, normalize=:pdf, label="sampled x")
    # histogram!(samples_of_y, weights=weighting, normalize=:pdf, label="sampled y")
    plot!(x->pdf(Normal(empirical_μ_x, empirical_σ_x), x), -10, 10, lw=4, color=:green, label="empirical")
    plot!(x->pdf(Normal(theoretical_μ, theoretical_σ), x), -10, 10, lw=1, color=:red, label="theoretical")
end

# test_binary_gated_copy_factor_2(2.0, 1.0, 1.9, 0.9, 0.5)

function test_binary_gated_copy_factor_3(μ_x::Float64, σ_x::Float64, μ_y::Float64, σ_y::Float64, p::Float64)
    no_samples = 100000000

    normal_x = Normal(μ_x, σ_x)
    normal_y = Normal(μ_y, σ_y)
    bernoulli = Bernoulli(p)

    samples_of_x = rand(normal_x, no_samples)
    samples_of_y = rand(normal_y, no_samples)
    binary_samples = rand(bernoulli, no_samples)

    weighting = Vector{Float64}(undef, no_samples)

    dirac = Normal(0, 0.01)

    for i in 1:no_samples
        weighting[i] = pdf(dirac, samples_of_y[i] - samples_of_x[i] * binary_samples[i])
    end
    
    empirical_μ_x = sum(binary_samples .* weighting) / sum(weighting)

    p_0 = pdf(Normal(μ_y, σ_y), 0)
    p_1 = pdf(Normal(μ_y-μ_x, sqrt(σ_y^2 + σ_x^2)), 0)

    t = log(p/(1-p)) + log(p_1/p_0)
    theoretical_μ_x = (1/(1+exp(-t)))

    println("theoretical_μ_x: $theoretical_μ_x")
    println("empirical_μ_x: $empirical_μ_x")
    

end

test_binary_gated_copy_factor_3(2.0, 1.0, 0.0, 0.9, 0.5)
