mutable struct Binary
    θ::Float64      # probability of success in natural parameterization
                    # = logit(p) = log(p/(1-p))
end

BinaryUniform() = Binary(0.0)

function BinaryByProbability(p) 
    if (p < 0.0 || p > 1.0)
        error("Probability must be in (0, 1)")
    end
    if (p == 0.0) 
        return @show Binary(-Inf)
    elseif (p == 1.0)
        return @show Binary(Inf)
    else
        return Binary(log(p/(1-p)))
    end
end

function gmean(b::Binary) 
    if (b.θ == -Inf)
        return 0.0
    elseif (b.θ == Inf)
        return 1.0
    else
        return 1.0/(1.0 + exp(-b.θ))
    end
end

function variance(b::Binary) 
    if (b.θ == -Inf || b.θ == Inf)
        return 0.0
    else
        return exp(b.θ)/(1.0 + exp(b.θ))^2
    end
end

function Base.:*(b1::Binary, b2::Binary)
    if (b1.θ == -Inf && b2.θ == +Inf) || (b1.θ == +Inf && b2.θ == -Inf)
        @warn("Multiplication of B(0) and B(1) is undefined")
        return @show Binary(0.0)
    elseif (b1.θ == -Inf || b2.θ == -Inf)
        return @show Binary(-Inf)
    elseif (b1.θ == Inf || b2.θ == Inf)
        return @show Binary(Inf)
    else
        return Binary(b1.θ + b2.θ)
    end
end

function Base.:/(b1::Binary, b2::Binary)
    if (b1.θ == -Inf && b2.θ == -Inf) || (b1.θ == +Inf && b2.θ == +Inf)
        @warn("Division of B(0) and B(1) is undefined")
        return @show Binary(0.0)
    elseif (b1.θ == +Inf || b2.θ == -Inf)
        return @show Binary(+Inf)
    elseif (b1.θ == -Inf || b2.θ == +Inf)
        return @show Binary(-Inf)
    else
        return Binary(b1.θ - b2.θ)
    end
end

function Base.isnan(b::Binary)
    return isnan(b.θ)
end

function Base.isinf(b::Binary)
    return isinf(b.θ)
end

function Base.show(io::IO, b::Binary)
    if (b.θ == -Inf)
        print(io, "Binary(p = 0.0)")
    elseif (b.θ == Inf)
        print(io, "Binary(p = 1.0)")
    else
        print(io, "Binary(p = $(round(gmean(b), digits=4)))")
    end
end
