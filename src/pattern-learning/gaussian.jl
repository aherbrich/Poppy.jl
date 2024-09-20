mutable struct Gaussian   
    τ::Float64          # precision mean τ = μ/σ² = μ⋅ρ
    ρ::Float64          # precision ρ = 1/σ²

    Gaussian(τ, ρ) = (ρ < 0.0 || isnan(ρ) || isnan(τ) || isinf(τ)) ? error("Invalid Gaussian parameters") : new(τ, ρ)
end

function GaussianStandard()
    return Gaussian(0.0, 1.0)
end

function GaussianUniform()
    return Gaussian(0.0, 0.0)
end

function GaussianDirac(μ)
    if isinf(μ) || isnan(μ)
        error("Dirac delta must have finite location")
    end

    @warn "You are creating a Dirac delta distribution - check if this is what you intended"

    return Gaussian(μ, +Inf)
end

function GaussianByMeanPrecision(τ, ρ)
    if (ρ == 0.0)
        error("You are creating a uniform with the 'GaussianByMeanPrecision' constructor - use 'GaussianUniform' instead")
    elseif (ρ == +Inf)
        error("You are creating a Dirac delta with the 'GaussianByMeanPrecision' constructor - use 'GaussianDirac' instead")
    else
        return Gaussian(τ, ρ)
    end
end

function GaussianByMeanVariance(μ, σ²)
    if (σ² == 0.0)
        error("You are creating a Dirac delta with the 'GaussianByMeanVariance' constructor - use 'GaussianDirac' instead")
    elseif (σ² == +Inf)
        error("You are creating a uniform with the 'GaussianByMeanVariance' constructor - use 'GaussianUniform' instead")
    else
        return Gaussian(μ/σ², 1.0/σ²)
    end
end

function update!(g1::Gaussian, g2::Gaussian)
    if (g2.ρ < 0.0 || isnan(g2.ρ) || isnan(g2.τ) || isinf(g2.τ))
        error("Invalid Gaussian parameters in update!")
    end

    g1.τ = g2.τ
    g1.ρ = g2.ρ
end

function unsafe_update!(g1::Gaussian, g2::Gaussian)
    if (isnan(g2.ρ) || isnan(g2.τ) || isinf(g2.τ))
        error("Invalid Gaussian parameters in update!")
    end

    if g2.ρ < 0.0
        # @warn("negative precision in update")
    end

    g1.τ = g2.τ
    g1.ρ = g2.ρ
end

function mean(g::Gaussian) 
    if isdirac(g)
        @warn "You called mean on a Dirac delta - check if this is what you intended"
        return g.τ
    elseif isuniform(g)
        @warn "You called mean on a uniform distribution - check if this is what you intended"
        return 0.0
    else
        return  g.τ/g.ρ
    end
end

function variance(g::Gaussian)
    if isdirac(g)
        @warn "You called variance on a Dirac delta - check if this is what you intended"
        return 0.0
    elseif isuniform(g)
        @warn "You called variance on a uniform distribution - check if this is what you intended"
        return +Inf
    else
        return 1.0/g.ρ
    end
end

function absdiff(g1::Gaussian, g2::Gaussian)
    # if isuniform(g1) || isuniform(g2) || isdirac(g1) || isdirac(g2)
    #     @warn "You are computing the absolute difference between uniform or Dirac delta distributions - check if this is what you intended"
    # end
    
    return max(abs(g1.τ - g2.τ), sqrt(abs(g1.ρ - g2.ρ)))
end

function Base.:*(g1::Gaussian, g2::Gaussian)
    if (isdirac(g1) && isdirac(g2) && g1.τ != g2.τ)
        error("Product of two Dirac deltas at different locations undefined")
    end

    if isdirac(g1)
        return GaussianDirac(g1.τ)
    elseif isdirac(g2)
        return GaussianDirac(g2.τ)
    else
        error_if_uniform(g1)
        error_if_uniform(g2)
        return Gaussian(g1.τ + g2.τ, g1.ρ + g2.ρ)
    end
end

function Base.:/(g1::Gaussian, g2::Gaussian)
    if isdirac(g2) 
        if !isdirac(g1) || g1.τ != g2.τ
            error("Division by Dirac deltas is only valid if dividing Dirac delta with same location")
        end

        return GaussianUniform()
    end

    if isdirac(g1)
        return GaussianDirac(g1.τ)
    end

    error_if_uniform(g1)
    error_if_uniform(g2)

    if g1.ρ - g2.ρ < 0.0 
        println("$(sqrt(variance(g1))) - $(sqrt(variance(g2)))")
        error("Division of g1 and g2 would result in negative precision")
    elseif abs(g1.ρ - g2.ρ) < eps()
        return GaussianUniform()
    else
        return Gaussian(g1.τ - g2.τ, g1.ρ - g2.ρ)
    end
end

function unsafe_division(g1::Gaussian, g2::Gaussian)
    if isdirac(g2) 
        if !isdirac(g1) || g1.τ != g2.τ
            error("Division by Dirac deltas is only valid if dividing Dirac delta with same location")
        end

        return GaussianUniform()
    end

    if isdirac(g1)
        return GaussianDirac(g1.τ)
    end

    error_if_uniform(g1)
    error_if_uniform(g2)

    if g1.ρ - g2.ρ < 0.0
        # @warn("Division of g1 and g2 would result in negative precision")
        g = Gaussian(g1.τ - g2.τ, 0.0)
        g.ρ = g1.ρ - g2.ρ
        return g
    elseif abs(g1.ρ - g2.ρ) < eps()
        return GaussianUniform()
    else
        return Gaussian(g1.τ - g2.τ, g1.ρ - g2.ρ)
    end
end

function Base.show(io::IO, g::Gaussian)
    if isuniform(g)
        print(io, "N(μ=0, σ²=Inf)")
    elseif isdirac(g)
        print(io, "N(μ=$(g.τ), σ²=0)")
    else
        print(io, "N(μ = ", round(mean(g), digits=4), ", σ = ", "$((variance(g) < 0.0) ? "-" : "")", round(sqrt(abs(variance(g))), digits=4), ")")
    end
end

function isdirac(g::Gaussian)
    return g.ρ == +Inf
end

function isuniform(g::Gaussian)
    if g.ρ == 0.0
        if g.τ != 0.0
            error("Uniform distribution must have mean 0")
        end
        return true
    end

    return false
end

function error_if_uniform(g::Gaussian)
    if g.ρ == 0.0 && g.τ != 0.0
        error("Uniform distribution must have mean 0")
    end
end

# using Distributions
# using Plots

# function message_incoming(x)
#     return x > 0 ? 1 : 0
# end

# function message_outgoing(g::Gaussian)
#     normal = Normal(mean(g), sqrt(variance(g)))
#     return x -> pdf(normal, x)
# end

# function true_posterior(g::Gaussian)
#     normalization = 1 - cdf(Normal(mean(g), sqrt(variance(g))), 0)
#     return x -> message_incoming(x) * message_outgoing(g)(x) / normalization
# end

# function approximate_posterior(g::Gaussian)   
#     return x -> pdf(Normal(mean(g), sqrt(variance(g))), x)
# end

# function approximate_incoming(g::Gaussian)
#     return x -> pdf(Normal(mean(g), sqrt(variance(g))), x)
# end

# function v(t)
#     normal = Normal(0, 1)
#     return pdf(normal, t) / cdf(normal, t)
# end

# function w(t)
#     vt = v(t)
#     return vt * (vt + t)
# end

# out_msg = GaussianByMeanVariance(1.6, 1.0)

# approx_post_mean = mean(out_msg) + sqrt(variance(out_msg)) * v(mean(out_msg)/sqrt(variance(out_msg)))
# approx_post_var = variance(out_msg) * (1 - w(mean(out_msg)/sqrt(variance(out_msg))))

# approx_post = GaussianByMeanVariance(approx_post_mean, approx_post_var)
# approx_inc = approx_post / out_msg

# plot(message_outgoing(out_msg), -5, 5, label="Outgoing message", color=:green, lw=2)
# plot!(message_incoming, -5, 5, label="True incoming message", color=:blue, lw=2, legend=:topleft)
# plot!(true_posterior(out_msg), -5, 5, label="True posterior", color=:red, lw=2)


# plot!(approximate_posterior(approx_post), -5, 5, label="Approximate posterior", color=:red, linestyle=:dash, lw=2)
# plot!(approximate_incoming(approx_inc), -5, 5, label="Approximate incoming message", color=:blue, linestyle=:dash, lw=2)

# # savefig as png
# savefig("gaussian_good.png")