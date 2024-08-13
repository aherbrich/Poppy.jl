mutable struct Binary
    θ::Float64      # probability of success in natural parameterization
                    # = logit(p) = log(p/(1-p))
end

BinaryUniform() = Binary(0.0)

BinaryByProbability(p) = (p < 0.0 || p > 1.0) ? error("Probability must be in (0, 1)") : Binary(log(p/(1-p)))

gmean(b::Binary) = 1.0/(1.0 + exp(-b.θ))
variance(b::Binary) = exp(b.θ)/(1.0 + exp(b.θ))^2

function Base.:*(b1::Binary, b2::Binary)
    return Binary(b1.θ + b2.θ)
end

function Base.:/(b1::Binary, b2::Binary)
    return Binary(b1.θ - b2.θ)
end

function Base.isnan(b::Binary)
    return isnan(b.θ)
end

function Base.isinf(b::Binary)
    return isinf(b.θ)
end

function Base.show(io::IO, b::Binary)
    print(io, "Binary(p = $(round(gmean(b), digits=4)))")
end
