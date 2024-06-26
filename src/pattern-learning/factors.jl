using Distributions

abstract type Factor end
struct GaussianFactor <: Factor
    x::Gaussian
    msg_to_x::Gaussian
    prior::Gaussian
end

function GaussianFactor(x::Gaussian, prior::Gaussian)
    msg_to_x = GaussianUniform()
    return GaussianFactor(x, msg_to_x, prior)
end

function update_msg_to_x!(f::GaussianFactor)
    msg_back = f.x / f.msg_to_x
    
    # update the message to x
    f.msg_to_x.τ = f.prior.τ
    f.msg_to_x.ρ = f.prior.ρ

    # update the distribution of x
    updated_x = msg_back * f.msg_to_x
    diff = absdiff(f.x, updated_x)
    f.x.τ = updated_x.τ
    f.x.ρ = updated_x.ρ

    return diff
end

struct GaussianMeanFactor <: Factor
    x::Gaussian
    y::Gaussian
    msg_to_x::Gaussian
    msg_to_y::Gaussian
    β::Float64
end

function GaussianMeanFactor(x::Gaussian, y::Gaussian, β::Float64)
    return GaussianMeanFactor(x, y, GaussianUniform(), GaussianUniform(), β)
end

function update_msg_to_x!(f::GaussianMeanFactor)
    msg_back = f.x / f.msg_to_x
    msg_incoming = f.y / f.msg_to_y

    # update the message to x
    c = 1.0 / (1.0 + f.β * msg_incoming.ρ)
    f.msg_to_x.τ = c * msg_incoming.τ
    f.msg_to_x.ρ = c * msg_incoming.ρ

    # update the distribution of x
    updated_x = msg_back * f.msg_to_x
    diff = absdiff(f.x, updated_x)
    f.x.τ = updated_x.τ
    f.x.ρ = updated_x.ρ

    return diff
end

function update_msg_to_y!(f::GaussianMeanFactor)
    msg_back = f.y / f.msg_to_y
    msg_incoming = f.x / f.msg_to_x

    # update the message to y
    c = 1.0 / (1.0 + f.β * msg_incoming.ρ)
    f.msg_to_y.τ = c * msg_incoming.τ
    f.msg_to_y.ρ = c * msg_incoming.ρ   

    # update the distribution of y
    updated_y = msg_back * f.msg_to_y
    diff = absdiff(f.y, updated_y)
    f.y.τ = updated_y.τ
    f.y.ρ = updated_y.ρ

    return diff
end

struct WeightedSumFactor <: Factor
    x::Gaussian
    y::Gaussian
    z::Gaussian
    msg_to_x::Gaussian
    msg_to_y::Gaussian
    msg_to_z::Gaussian
    a::Float64
    b::Float64
end

function WeightedSumFactor(x::Gaussian, y::Gaussian, z::Gaussian, a::Float64, b::Float64)
    return WeightedSumFactor(x, y, z, GaussianUniform(), GaussianUniform(), GaussianUniform(), a, b)
end

function update_msg_to_x!(f::WeightedSumFactor)
    msg_back = f.x / f.msg_to_x
    msg_incoming_y = f.y / f.msg_to_y
    msg_incoming_z = f.z / f.msg_to_z

    # update the message to x
    updated_msg_to_x = (msg_incoming_y.ρ == 0.0 || msg_incoming_z.ρ == 0.0) ? 
        GaussianUniform() :
        GaussianByMeanVariance(
            gmean(msg_incoming_z) / f.a - f.b / f.a * gmean(msg_incoming_y),
            variance(msg_incoming_z) / f.a^2 + f.b^2 / f.a^2 * variance(msg_incoming_y)
        )
    f.msg_to_x.τ = updated_msg_to_x.τ
    f.msg_to_x.ρ = updated_msg_to_x.ρ

    # update the distribution of x
    updated_x = msg_back * f.msg_to_x
    diff = absdiff(f.x, updated_x)
    f.x.τ = updated_x.τ
    f.x.ρ = updated_x.ρ

    return diff
end

function update_msg_to_y!(f::WeightedSumFactor)
    msg_back = f.y / f.msg_to_y
    msg_incoming_x = f.x / f.msg_to_x
    msg_incoming_z = f.z / f.msg_to_z

    # update the message to y
    updated_msg_to_y = (msg_incoming_x.ρ == 0.0 || msg_incoming_z.ρ == 0.0) ? 
        GaussianUniform() :
        GaussianByMeanVariance(
            gmean(msg_incoming_z) / f.b - f.a / f.b * gmean(msg_incoming_x),
            variance(msg_incoming_z) / f.b^2 + f.a^2 / f.b^2 * variance(msg_incoming_x)
        )
    f.msg_to_y.τ = updated_msg_to_y.τ
    f.msg_to_y.ρ = updated_msg_to_y.ρ

    # update the distribution of y
    updated_y = msg_back * f.msg_to_y
    diff = absdiff(f.y, updated_y)
    f.y.τ = updated_y.τ
    f.y.ρ = updated_y.ρ

    return diff
end

function update_msg_to_z!(f::WeightedSumFactor)
    msg_back = f.z / f.msg_to_z
    msg_incoming_x = f.x / f.msg_to_x
    msg_incoming_y = f.y / f.msg_to_y

    # update the message to z
    updated_msg_to_z = (msg_incoming_x.ρ == 0.0 || msg_incoming_y.ρ == 0.0) ? 
        GaussianUniform() :
        GaussianByMeanVariance(
            f.a * gmean(msg_incoming_x) + f.b * gmean(msg_incoming_y),
            f.a^2 * variance(msg_incoming_x) + f.b^2 * variance(msg_incoming_y)
        )
    f.msg_to_z.τ = updated_msg_to_z.τ
    f.msg_to_z.ρ = updated_msg_to_z.ρ

    # update the distribution of z
    updated_z = msg_back * f.msg_to_z
    diff = absdiff(f.z, updated_z)
    f.z.τ = updated_z.τ
    f.z.ρ = updated_z.ρ

    return diff
end


struct GreaterThanFactor <: Factor
    x::Gaussian
    msg_to_x::Gaussian
end

function GreaterThanFactor(x::Gaussian)
    return GreaterThanFactor(x, GaussianUniform())
end

function v(t)
    normal = Normal()
    denom = cdf(normal, t)
    if denom < 1e-10
        return -t
    else
        return pdf(normal, t) / denom
    end
end

function w(t)
    normal = Normal()
    denom = cdf(normal, t)
    if denom < 1e-10
        return (t < 0.0) ? 1.0 : 0.0
    else
        return v(t) * (v(t) + t)
    end
end

function update_msg_to_x!(f::GreaterThanFactor)
    msg_back = f.x / f.msg_to_x
    μ = gmean(msg_back)
    σ = sqrt(variance(msg_back))
    c = μ / σ

    truncated_mean = μ + σ * v(c)
    truncated_variance = σ^2 * (1 - w(c))

    truncated_gaussian = GaussianByMeanVariance(
        truncated_mean,
        truncated_variance
    )

    # update the message to x
    updated_msg_to_x = truncated_gaussian / msg_back
    f.msg_to_x.τ = updated_msg_to_x.τ
    f.msg_to_x.ρ = updated_msg_to_x.ρ

    # update the distribution of x
    diff = absdiff(f.x, truncated_gaussian)
    f.x.τ = truncated_gaussian.τ
    f.x.ρ = truncated_gaussian.ρ

    return diff
end
