mutable struct Binary
    θ::Float64      # probability of success in natural parameterization
                    # = logit(p) = log(p/(1-p))
end

BinaryUniform() = Binary(0.0)

function BinaryByProbability(p) 
    if (p < 0.0 || p > 1.0)
        error("Probability must be in (0, 1) but is $p")
    end
    if (p == 0.0)
        return Binary(-Inf)
    elseif (p == 1.0)
        return Binary(Inf)
    else
        return Binary(log(p/(1-p)))
    end
end

function update!(b1::Binary, b2::Binary)
    if isnan(b1.θ) || isnan(b2.θ)
        error("Invalid Binary parameters in update!")
    end

    b1.θ = b2.θ
end 
function mean(b::Binary) 
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

function kl_divergence(b1::Binary, b2::Binary)
    p1 = mean(b1)
    p2 = mean(b2)

    if p1 == 0.0 
        if p2 == 0.0
            return 0.0
        elseif p2 == 1.0 
            return Inf
        else
            return -log(1-q)
        end
    elseif p1 == 1.0
        if p2 == 0.0
            return Inf
        elseif p2 == 1.0
            return 0.0
        else
            return -log(q)
        end
    else
        return p1*log(p1/p2) + (1-p1)*log((1-p1)/(1-p2))
    end
end

function Base.:*(b1::Binary, b2::Binary)
    if (b1.θ == -Inf && b2.θ == +Inf) || (b1.θ == +Inf && b2.θ == -Inf)
        @warn("Multiplication of B(0) and B(1) is undefined")
        return Binary(0.0)
    elseif (b1.θ == -Inf || b2.θ == -Inf)
        return Binary(-Inf)
    elseif (b1.θ == Inf || b2.θ == Inf)
        return Binary(Inf)
    else
        return Binary(b1.θ + b2.θ)
    end
end

function Base.:/(b1::Binary, b2::Binary)
    if (b1.θ == -Inf && b2.θ == -Inf) || (b1.θ == +Inf && b2.θ == +Inf)
        @warn("Division of B(0) and B(1) is undefined")
        return Binary(0.0)
    elseif (b1.θ == +Inf || b2.θ == -Inf)
        return Binary(+Inf)
    elseif (b1.θ == -Inf || b2.θ == +Inf)
        return Binary(-Inf)
    else
        return Binary(b1.θ - b2.θ)
    end
end

function Base.show(io::IO, b::Binary)
    if (b.θ == -Inf)
        print(io, "Binary(p = 0.0)")
    elseif (b.θ == Inf)
        print(io, "Binary(p = 1.0)")
    else
        print(io, "Binary(p = $(round(mean(b), digits=4)))")
    end
end
