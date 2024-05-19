struct GaussianFactor
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
    f.x.τ = updated_x.τ
    f.x.ρ = updated_x.ρ
end

struct GaussianMeanFactor
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
    f.x.τ = updated_x.τ
    f.x.ρ = updated_x.ρ
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
    f.y.τ = updated_y.τ
    f.y.ρ = updated_y.ρ
end

struct WeightedSumFactor
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
    updated_msg_to_x = GaussianByMeanVariance(
        mean(msg_incoming_z) / a - b / a * mean(msg_incoming_y),
        variance(msg_incoming_z) / a^2 + b^2 / a^2 * variance(msg_incoming_y)
    )

    # update the distribution of x
    updated_x = msg_back * f.msg_to_x
    f.x.τ = updated_x.τ
    f.x.ρ = updated_x.ρ
end

function update_msg_to_y!(f::WeightedSumFactor)
    msg_back = f.y / f.msg_to_y
    msg_incoming_x = f.x / f.msg_to_x
    msg_incoming_z = f.z / f.msg_to_z

    # update the message to y
    updated_msg_to_y = GaussianByMeanVariance(
        mean(msg_incoming_z) / b - a / b * mean(msg_incoming_x),
        variance(msg_incoming_z) / b^2 + a^2 / b^2 * variance(msg_incoming_x)
    )

    # update the distribution of y
    updated_y = msg_back * f.msg_to_y
    f.y.τ = updated_y.τ
    f.y.ρ = updated_y.ρ
end

function update_msg_to_z!(f::WeightedSumFactor)
    msg_back = f.z / f.msg_to_z
    msg_incoming_x = f.x / f.msg_to_x
    msg_incoming_y = f.y / f.msg_to_y

    # update the message to z
    updated_msg_to_z = GaussianByMeanVariance(
        f.a * mean(msg_incoming_x) + f.b * mean(msg_incoming_y),
        f.a^2 * variance(msg_incoming_x) + f.b^2 * variance(msg_incoming_y)
    )
    f.msg_to_z.τ = updated_msg_to_z.τ
    f.msg_to_z.ρ = updated_msg_to_z.ρ

    # update the distribution of z
    updated_z = msg_back * f.msg_to_z
    f.z.τ = updated_z.τ
    f.z.ρ = updated_z.ρ
end


struct GreaterThanFactor
    x::Gaussian
    msg_to_x::Gaussian
end

function GreaterThanFactor(x::Gaussian)
    return GreaterThanFactor(x, GaussianUniform())
end

function v(t)
    normal = Normal()
    return pdf(normal, t) / cdf(normal, t)
end

function w(t)
    return v(t) * (v(t) + t)
end

function update_msg_to_x!(f::GreaterThanFactor)
    msg_back = f.x / f.msg_to_x
    μ = mean(msg_back)
    σ = sqrt(variance(msg_back))

    truncated_gaussian = GaussianByMeanVariance(
        μ + σ * v(μ / σ),
        σ^2 * (1 - w(μ / σ))
    )

    # update the message to x
    updated_msg_to_x = truncated_gaussian / f.x
    f.msg_to_x.τ = updated_msg_to_x.τ
    f.msg_to_x.ρ = updated_msg_to_x.ρ

    # update the distribution of x
    f.x.τ = truncated_gaussian.τ
    f.x.ρ = truncated_gaussian.ρ
end
