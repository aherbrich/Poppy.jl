mutable struct Gaussian   
    τ::Float64          # precision mean τ = μ/σ² = μ⋅ρ
    ρ::Float64          # precision ρ = 1/σ²

    Gaussian(τ, ρ) = (ρ < 0.0) ? error("Precision must be positive") : new(τ, ρ)
end

Gaussian() = Gaussian(0.0, 1.0)
GaussianUniform() = Gaussian(0.0, 0.0)

function GaussianDirac(μ) 
    return Gaussian(μ, +Inf)
end

function GaussianByMeanVariance(μ, σ²)
    if (σ² == 0.0)
        return @show GaussianDirac(μ)
    else
        return Gaussian(μ/σ², 1.0/σ²)
    end
end

function gmean(g::Gaussian) 
    if isdirac(g)
        return @show g.τ
    else
        return  g.τ/g.ρ
    end
end

function variance(g::Gaussian)
    if isdirac(g)
        return @show 0.0
    else
        1.0/g.ρ
    end
end

absdiff(g1::Gaussian, g2::Gaussian) = max(abs(g1.τ - g2.τ), sqrt(abs(g1.ρ - g2.ρ)))

function Base.:*(g1::Gaussian, g2::Gaussian)
    if (isdirac(g1) && isdirac(g2) && g1.τ != g2.τ)
        error("Product of two Dirac deltas at different locations undefined")
    end

    if isdirac(g1)
        return @show g1
    elseif isdirac(g2)
        return @show g2
    else
        return Gaussian(g1.τ + g2.τ, g1.ρ + g2.ρ)
    end
end

function Base.:/(g1::Gaussian, g2::Gaussian)
    if isdirac(g2) 
        if !isdirac(g1) || g1.τ != g2.τ
            error("Division by Dirac deltas is only valid if dividing Dirac delta with same location")
        end

        return @show GaussianUniform()
    end

    if isdirac(g1)
        return @show g1
    end

    if g1.ρ - g2.ρ < 0.0 
        println("$(g1.ρ) - $(g2.ρ)")
        error("Division of g1 and g2 would result in negative precision")
    elseif abs(g1.ρ - g2.ρ) < eps()
        return Gaussian(g1.τ - g2.τ, 0.0)
    else
        return Gaussian(g1.τ - g2.τ, g1.ρ - g2.ρ)
    end
end

function Base.:(==)(g1::Gaussian, g2::Gaussian)
    return g1.τ - g2.τ < eps(Float32) && g1.ρ - g2.ρ < eps(Float32)
end

function Base.show(io::IO, g::Gaussian)
    if g.ρ == 0.0
        print(io, "N(μ=0, σ²=Inf)")
    elseif g.ρ == +Inf
        print(io, "N(μ=$(g.τ), σ²=0)")
    else
        print(io, "N(μ = ", round(gmean(g), digits=4), ", σ = ", round(sqrt(variance(g)), digits=4), ")")
    end
end

function Base.isnan(g::Gaussian)
    return isnan(g.τ) || isnan(g.ρ)
end

function isdirac(g::Gaussian)
    return g.ρ == +Inf
end

function Base.isinf(g::Gaussian)
    return isinf(g.τ) || isinf(g.ρ)
end
