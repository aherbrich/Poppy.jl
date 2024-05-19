mutable struct Gaussian   
    τ ::Float64        # precision mean τ = μ/σ² = μ⋅ρ
    ρ ::Float64        # precision ρ = 1/σ²

    Gaussian(τ, ρ) = (ρ < 0.0) ? error("Precision must be positive") : new(τ, ρ)
end

Gaussian() = Gaussian(0.0, 1.0)
GaussianUniform() = Gaussian(0.0, 0.0)

GaussianByMeanVariance(μ, σ²) = Gaussian(μ/σ², 1.0/σ²)

mean(g::Gaussian) = g.τ/g.ρ

variance(g::Gaussian) = 1.0/g.ρ

function Base.:*(g1::Gaussian, g2::Gaussian)
    return Gaussian(g1.τ + g2.τ, g1.ρ + g2.ρ)
end

function Base.:/(g1::Gaussian, g2::Gaussian)
    return Gaussian(g1.τ - g2.τ, g1.ρ - g2.ρ)
end

function Base.show(io::IO, g::Gaussian)
    if g.ρ == 0.0
        print(io, "N(μ=0, σ²=Inf)")
    else
        print(io, "N(μ = ", mean(g), ", σ = ", sqrt(variance(g)), ")")
    end
end
