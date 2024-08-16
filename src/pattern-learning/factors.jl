using Distributions

abstract type Factor end
struct GaussianFactor <: Factor
    x::Gaussian
    msg_to_x::Gaussian
    prior::Gaussian
end

function Base.show(io::IO, f::GaussianFactor)
    println(io, "GAUSSIAN FACTOR")
    println(io, "X: $(f.x)")
    println(io, "Msg to X: $(f.msg_to_x)")
    println(io, "Prior: $(f.prior)")
end

function GaussianFactor(x::Gaussian, prior::Gaussian)
    msg_to_x = GaussianUniform()
    return GaussianFactor(x, msg_to_x, prior)
end

function update_msg_to_x!(f::GaussianFactor)
    msg_back = f.x / f.msg_to_x
    
    # UPDATE THE MESSAGE TO X
    f.msg_to_x.τ = f.prior.τ
    f.msg_to_x.ρ = f.prior.ρ

    # UPDATE THE DISTRIBUTION OF X
    updated_x = msg_back * f.msg_to_x
    diff = absdiff(f.x, updated_x)
    f.x.τ = updated_x.τ
    f.x.ρ = updated_x.ρ

    if isnan(f.x) || isinf(f.x)
        println(f)
        error("NAN/INF")
    end
    return diff
end

struct GaussianMeanFactor <: Factor
    x::Gaussian
    y::Gaussian
    msg_to_x::Gaussian
    msg_to_y::Gaussian
    beta_squared::Float64
end

function Base.show(io::IO, f::GaussianMeanFactor)
    println(io, "GAUSSIAN MEAN FACTOR")
    println(io, "X: $(f.x)")
    println(io, "Y: $(f.y)")
    println(io, "Msg to X: $(f.msg_to_x)")
    println(io, "Msg to Y: $(f.msg_to_y)")
    println(io, "Beta squared: $(f.beta_squared)")
end

function GaussianMeanFactor(x::Gaussian, y::Gaussian, beta_squared::Float64)
    return GaussianMeanFactor(x, y, GaussianUniform(), GaussianUniform(), beta_squared)
end

function update_msg_to_x!(f::GaussianMeanFactor)
    msg_back = f.x / f.msg_to_x
    msg_incoming = f.y / f.msg_to_y

    # UPDATE THE MESSAGE TO X
    c = 1.0 / (1.0 + f.beta_squared * msg_incoming.ρ)
    f.msg_to_x.τ = c * msg_incoming.τ
    f.msg_to_x.ρ = c * msg_incoming.ρ

    # UPDATE THE DISTRIBUTION OF X
    updated_x = msg_back * f.msg_to_x
    diff = absdiff(f.x, updated_x)
    f.x.τ = updated_x.τ
    f.x.ρ = updated_x.ρ

    if isnan(f.x) || isinf(f.x)
        println(f)
        error("NAN/INF")
    end

    return diff
end

function update_msg_to_y!(f::GaussianMeanFactor)
    msg_back = f.y / f.msg_to_y
    msg_incoming = f.x / f.msg_to_x

    # UPDATE THE MESSAGE TO Y
    c = 1.0 / (1.0 + f.beta_squared * msg_incoming.ρ)
    f.msg_to_y.τ = c * msg_incoming.τ
    f.msg_to_y.ρ = c * msg_incoming.ρ   

    # UPDATE THE DISTRIBUTION OF Y
    updated_y = msg_back * f.msg_to_y
    diff = absdiff(f.y, updated_y)
    f.y.τ = updated_y.τ
    f.y.ρ = updated_y.ρ

    if isnan(f.y) || isinf(f.y)
        println(f)
        error("NAN/INF")
    end

    return diff
end

struct SumFactor <: Factor
    summands::Vector{Gaussian}
    sum::Gaussian
    msg_to_summands::Vector{Gaussian}
    msg_to_sum::Gaussian
end

function Base.show(io::IO, f::SumFactor)
    println(io, "SUM FACTOR")
    println(io, "Sum: $(f.sum)")
    println(io, "Summands: $(f.summands)")
    println(io, "Msg to sum: $(f.msg_to_sum)")
    println(io, "Msg to summands: $(f.msg_to_summands)")
end

function SumFactor(summands::Vector{Gaussian}, sum::Gaussian)
    msg_to_summands = [GaussianUniform() for _ in summands]
    return SumFactor(summands, sum, msg_to_summands, GaussianUniform())
end

function update_msg_to_sum!(f::SumFactor)
    msg_back = f.sum / f.msg_to_sum
    
    # PRECISION & PRECISION MEAN OF MSG TO SUM
    incoming_msgs = [f.summands[i] / f.msg_to_summands[i] for i in eachindex(f.summands)]

    μ = 0.0
    σ2 = 0.0
    for msg in incoming_msgs
        μ += gmean(msg)
        σ2 += variance(msg)
    end
    precision = 1.0 / σ2
    precision_mean = precision * μ

    # UPDATE THE MESSAGE TO SUM
    f.msg_to_sum.τ = precision_mean
    f.msg_to_sum.ρ = precision

    # UPDATE THE DISTRIBUTION OF SUM
    updated_sum = msg_back * f.msg_to_sum
    diff = absdiff(f.sum, updated_sum)
    f.sum.τ = updated_sum.τ
    f.sum.ρ = updated_sum.ρ

    if isnan(f.sum) || isinf(f.sum)
        println(f)
        error("NAN/INF")
    end


    return diff
end


function update_msg_to_summands!(f::SumFactor)
    inc_msg_from_sum = f.sum / f.msg_to_sum
    inc_msgs_from_summands = [f.summands[j] / f.msg_to_summands[j] for j in eachindex(f.summands)]

    b = 0.0
    c = 0.0
    for msg in inc_msgs_from_summands
        b += variance(msg)
        c += gmean(msg)
    end
    
    max_diff = 0.0
    for i in eachindex(f.summands)
        msg_back = f.summands[i] / f.msg_to_summands[i]
        
        # UPDATE THE MESSAGE TO SUMMAND I
        denom = 1.0 + inc_msg_from_sum.ρ * (b - variance(inc_msgs_from_summands[i]))
        f.msg_to_summands[i].ρ = inc_msg_from_sum.ρ / denom
        f.msg_to_summands[i].τ = (inc_msg_from_sum.τ - inc_msg_from_sum.ρ * (c - gmean(inc_msgs_from_summands[i]))) / denom
    
        # UPDATE THE DISTRIBUTION OF SUMMAND I
        updated_summand = msg_back * f.msg_to_summands[i]
        diff = absdiff(f.summands[i], updated_summand)
        max_diff = max(max_diff, diff)
        f.summands[i].τ = updated_summand.τ
        f.summands[i].ρ = updated_summand.ρ

        if isnan(f.summands[i]) || isinf(f.summands[i])
            println(f)
            error("NAN/INF")
        end
    end
    
    return max_diff
end

struct DifferenceFactor <: Factor
    x::Gaussian
    y::Gaussian
    z::Gaussian
    msg_to_x::Gaussian
    msg_to_y::Gaussian
    msg_to_z::Gaussian
end

function Base.show(io::IO, f::DifferenceFactor)
    println(io, "DIFFERENCE FACTOR")
    println(io, "X: $(f.x)")
    println(io, "Y: $(f.y)")
    println(io, "Z: $(f.z)")
    println(io, "Msg to X: $(f.msg_to_x)")
    println(io, "Msg to Y: $(f.msg_to_y)")
    println(io, "Msg to Z: $(f.msg_to_z)")
end

function DifferenceFactor(x::Gaussian, y::Gaussian, z::Gaussian)
    return DifferenceFactor(x, y, z, GaussianUniform(), GaussianUniform(), GaussianUniform())
end

function update_msg_to_x!(f::DifferenceFactor)
    msg_back = f.x / f.msg_to_x

    # PRECISION & PRECISION MEAN OF MSG TO X
    msg_incoming_y = f.y / f.msg_to_y
    msg_incoming_z = f.z / f.msg_to_z

    precision = 0.0                        
    precision_mean = 0.0                    

    if (msg_incoming_z.ρ * msg_incoming_y.ρ) != 0.0
        denom = msg_incoming_y.ρ + msg_incoming_z.ρ
        precision = (msg_incoming_z.ρ * msg_incoming_y.ρ) / denom
        precision_mean = ((msg_incoming_z.τ * msg_incoming_y.ρ) + (msg_incoming_y.τ * msg_incoming_z.ρ)) / denom
    end

    # UPDATE THE MESSAGE TO X
    f.msg_to_x.τ = precision_mean
    f.msg_to_x.ρ = precision

    # UPDATE THE DISTRIBUTION OF X
    updated_x = msg_back * f.msg_to_x
    diff = absdiff(f.x, updated_x)
    f.x.τ = updated_x.τ
    f.x.ρ = updated_x.ρ

    if isnan(f.x) || isinf(f.x)
        println(f)
        error("NAN/INF")
    end

    return diff
end

function update_msg_to_y!(f::DifferenceFactor)
    msg_back = f.y / f.msg_to_y

    # PRECISION & PRECISION MEAN OF MSG TO Y
    msg_incoming_x = f.x / f.msg_to_x
    msg_incoming_z = f.z / f.msg_to_z

    precision = 0.0
    precision_mean = 0.0

    if (msg_incoming_x.ρ * msg_incoming_z.ρ) != 0.0
        denom = msg_incoming_z.ρ + msg_incoming_x.ρ
        precision = (msg_incoming_x.ρ * msg_incoming_z.ρ) / denom
        precision_mean = ((msg_incoming_x.τ * msg_incoming_z.ρ) - (msg_incoming_z.τ * msg_incoming_x.ρ)) / denom
    end

    # UPDATE THE MESSAGE TO Y
    f.msg_to_y.τ = precision_mean
    f.msg_to_y.ρ = precision

    # UPDATE THE DISTRIBUTION OF Y
    updated_y = msg_back * f.msg_to_y
    diff = absdiff(f.y, updated_y)
    f.y.τ = updated_y.τ
    f.y.ρ = updated_y.ρ

    if isnan(f.y) || isinf(f.y)
        println(f)
        error("NAN/INF")
    end

    return diff
end

function update_msg_to_z!(f::DifferenceFactor)
    msg_back = f.z / f.msg_to_z

    # PRECISION & PRECISION MEAN OF MSG TO Z
    msg_incoming_x = f.x / f.msg_to_x
    msg_incoming_y = f.y / f.msg_to_y

    precision = 0.0
    precision_mean = 0.0

    if (msg_incoming_x.ρ * msg_incoming_y.ρ) != 0.0
        denom = msg_incoming_y.ρ + msg_incoming_x.ρ
        precision = (msg_incoming_x.ρ * msg_incoming_y.ρ) / denom
        precision_mean = ((msg_incoming_x.τ * msg_incoming_y.ρ) - (msg_incoming_y.τ * msg_incoming_x.ρ)) / denom
    end

    # UPDATE THE MESSAGE TO Z
    f.msg_to_z.τ = precision_mean
    f.msg_to_z.ρ = precision

    # UPDATE THE DISTRIBUTION OF Z
    updated_z = msg_back * f.msg_to_z
    diff = absdiff(f.z, updated_z)
    f.z.τ = updated_z.τ
    f.z.ρ = updated_z.ρ

    if isnan(f.z) || isinf(f.z)
        println(f)
        error("NAN/INF")
    end

    return diff
end


struct GreaterThanFactor <: Factor
    x::Gaussian
    msg_to_x::Gaussian
end

function Base.show(io::IO, f::GreaterThanFactor)
    println(io, "GREATER THAN FACTOR")
    println(io, "X: $(f.x)")
    println(io, "Msg to X: $(f.msg_to_x)")
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

function v(t, p)
    normal = Normal()
    d = pdf(normal, t)
    c = cdf(normal, t)
    return ((1-2*p) * d) / ((1-2*p) * c + p)
end

function w(t)
    normal = Normal()
    if pdf(normal, t) < 1e-10
        return (t < 0.0) ? 1.0 : 0.0
    else
        return v(t) * (v(t) + t)
    end
end

function w(t, p)
    normal = Normal()
    return v(t, p) * (v(t, p) + t)
end

function update_msg_to_x!(f::GreaterThanFactor)
    msg_back = f.x / f.msg_to_x
    
    # PRECISION & PRECISION MEAN OF TRUNCATED GAUSSIAN (X)
    precision = 0.0
    precision_mean = 0.0

    if msg_back.ρ != 0.0
        a = msg_back.τ / sqrt(msg_back.ρ)
        precision = msg_back.ρ / (1 - w(a))
        precision_mean = (msg_back.τ + sqrt(msg_back.ρ) * v(a)) / (1 - w(a))
    end

    # UPDATE THE DISTRIBUTION OF X
    if isinf(precision)
        println(f)
    end

    truncated_gaussian = Gaussian(precision_mean, precision)

    if isnan(truncated_gaussian) || isinf(truncated_gaussian)
        println(f)
        error("NAN/INF ($(1-w(a)))")
    end
    diff = absdiff(f.x, truncated_gaussian)
    f.x.τ = truncated_gaussian.τ
    f.x.ρ = truncated_gaussian.ρ

    # UPDATE THE MESSAGE TO X
    updated_msg_to_x = f.x / msg_back
    f.msg_to_x.τ = updated_msg_to_x.τ
    f.msg_to_x.ρ = updated_msg_to_x.ρ

    return diff
end

struct SignConsistencyFactor <: Factor
    x::Gaussian
    s::Binary
    msg_to_x::Gaussian
    msg_to_s::Binary
end

function Base.show(io::IO, f::DifferenceFactor)
    println(io, "SIGN CONSISTENCY FACTOR")
    println(io, "X: $(f.x)")
    println(io, "S: $(f.s)")
    println(io, "Msg to X: $(f.msg_to_x)")
    println(io, "Msg to S: $(f.msg_to_s)")
end

function SignConsistencyFactor(x::Gaussian, s::Binary)
    return SignConsistencyFactor(x, s, GaussianUniform(), BinaryUniform())
end

function update_msg_to_s!(f::SignConsistencyFactor)
    msg_from_s = f.s / f.msg_to_s
    msg_from_x = f.x / f.msg_to_x

    # UPDATE THE MESSAGE TO S
    new_msg_to_s = BinaryByProbability(cdf(Normal(), msg_from_x.τ / sqrt(msg_from_x.ρ)))
    f.msg_to_s.θ = new_msg_to_s.θ

    # UPDATE THE DISTRIBUTION OF S
    new_marginal_of_s = msg_from_s * f.msg_to_s
    f.s.θ = new_marginal_of_s.θ

    if isnan(f.s) || isinf(f.s)
        println(f)
        error("NAN/INF")
    end

    # return absdiff ???
end


function update_msg_to_x!(f::SignConsistencyFactor)
    msg_from_x = f.x / f.msg_to_x
    msg_from_s = f.s / f.msg_to_s
    
    # PRECISION & PRECISION MEAN OF TRUNCATED GAUSSIAN (X)
    precision = 0.0
    precision_mean = 0.0

    if msg_from_x.ρ != 0.0
        c = -(msg_from_x.τ / sqrt(msg_from_x.ρ))
        p = gmean(msg_from_s)
        precision = msg_from_x.ρ / (1 - w(c, p))
        precision_mean = (msg_from_x.τ - sqrt(msg_from_x.ρ) * v(c, p)) / (1 - w(c, p))
    end

    # UPDATE THE DISTRIBUTION OF X
    if isinf(precision)
        println(f)
    end

    new_marginal_of_x = Gaussian(precision_mean, precision)

    if isnan(new_marginal_of_x) || isinf(new_marginal_of_x)
        println(f)
        error("NAN/INF ($(1-w(a, p)))")
    end
    diff = absdiff(f.x, new_marginal_of_x)
    f.x.τ = new_marginal_of_x.τ
    f.x.ρ = new_marginal_of_x.ρ

    # UPDATE THE MESSAGE TO X
    new_msg_to_x = f.x / msg_from_x
    f.msg_to_x.τ = new_msg_to_x.τ
    f.msg_to_x.ρ = new_msg_to_x.ρ

    return diff
end

struct BinaryGatedCopyFactor <: Factor
    x::Gaussian
    y::Gaussian
    s::Binary
    msg_to_x::Gaussian
    msg_to_y::Gaussian
    msg_to_s::Binary
end

function Base.show(io::IO, f::BinaryGatedCopyFactor)
    println(io, "BINARY GATED COPY FACTOR")
    println(io, "X: $(f.x)")
    println(io, "Y: $(f.y)")
    println(io, "S: $(f.s)")
    println(io, "Msg to X: $(f.msg_to_x)")
    println(io, "Msg to Y: $(f.msg_to_y)")
    println(io, "Msg to S: $(f.msg_to_s)")
end

function BinaryGatedCopyFactor(x::Gaussian, y::Gaussian, s::Binary)
    return BinaryGatedCopyFactor(x, y, s, GaussianUniform(), GaussianUniform(), BinaryUniform())
end

function update_msg_to_y!(f::BinaryGatedCopyFactor)
    msg_from_y = f.y / f.msg_to_y
    msg_from_x = f.x / f.msg_to_x
    msg_from_s = f.s / f.msg_to_s
    p = gmean(msg_from_s)
    
    # copy x case: if p == 1.0 then msg_to_y = msg_from_x
    if p == 1.0
        f.msg_to_y.τ = msg_from_x.τ
        f.msg_to_y.ρ = msg_from_x.ρ

        new_marginal_of_y = msg_from_y * f.msg_to_y
        diff = absdiff(f.y, new_marginal_of_y)
        f.y.τ = new_marginal_of_y.τ
        f.y.ρ = new_marginal_of_y.ρ

        return diff
    end

    if (p == 0.0) || (msg_from_x.ρ == 0.0)
        println(f)
        error("Result would be a Dirac delta")
    end

    while true
        μ_xy = (msg_from_x.τ + msg_from_y.τ) / (msg_from_x.ρ + msg_from_y.ρ)
        σ2_xy = 1.0 / (msg_from_x.ρ + msg_from_y.ρ)

        if msg_from_y.ρ == 0.0
            normalization = 1.0
        else
            g_0 = pdf(Normal(gmean(msg_from_y), sqrt(variance(msg_from_y))), 0)
            g_1 = pdf(Normal(gmean(msg_from_y) - gmean(msg_from_x), sqrt((msg_from_x.ρ + msg_from_y.ρ) / (msg_from_x.ρ * msg_from_y.ρ))), 0)

            normalization = g_1 / ((1 - p) * g_0 + p * g_1)
        end

        second_moment = p * (μ_xy^2 + σ2_xy) * normalization
        μ_y = p * μ_xy * normalization
        σ_y = sqrt(second_moment - μ_y^2)

        # UPDATE DISTRIBUTION OF Y
        new_marginal_of_y = GaussianByMeanVariance(μ_y, σ_y^2)
        if isnan(new_marginal_of_y) || isinf(new_marginal_of_y)
            println(f)
            error("NAN/INF")
        end

        if new_marginal_of_y.ρ - msg_from_y.ρ < eps()
            p *= 0.5
        else
            break
        end
    end

    diff = absdiff(f.y, new_marginal_of_y)
    f.y.τ = new_marginal_of_y.τ
    f.y.ρ = new_marginal_of_y.ρ

    # UPDATE THE MESSAGE TO Y
    new_msg_to_y = f.y / msg_from_y
    f.msg_to_y.τ = new_msg_to_y.τ
    f.msg_to_y.ρ = new_msg_to_y.ρ

    return diff
end

function update_msg_to_x!(f::BinaryGatedCopyFactor)
    msg_from_x = f.x / f.msg_to_x
    msg_from_y = f.y / f.msg_to_y
    msg_from_s = f.s / f.msg_to_s
    p = gmean(msg_from_s)
    
    # copy y case: if p == 1.0 then msg_to_x = msg_from_y
    if p == 1.0
        f.msg_to_x.τ = msg_from_y.τ
        f.msg_to_x.ρ = msg_from_y.ρ

        new_marginal_of_x = msg_from_x * f.msg_to_x
        diff = absdiff(f.x, new_marginal_of_x)
        f.x.τ = new_marginal_of_x.τ
        f.x.ρ = new_marginal_of_x.ρ

        return diff
    end
    
    # copy x case: then marg_x stays the same
    if p == 0.0 || msg_from_x.ρ == 0.0 || msg_from_y.ρ == 0.0
        new_msg_to_x = GaussianUniform()
        f.msg_to_x.τ = new_msg_to_x.τ
        f.msg_to_x.ρ = new_msg_to_x.ρ

        return 0.0
    end

    μ_xy = (msg_from_x.τ + msg_from_y.τ) / (msg_from_x.ρ + msg_from_y.ρ)
    σ2_xy = 1.0 / (msg_from_x.ρ + msg_from_y.ρ)

    g_0 = pdf(Normal(gmean(msg_from_y), sqrt(variance(msg_from_y))), 0)
    g_1 = pdf(Normal(gmean(msg_from_y) - gmean(msg_from_x), sqrt((msg_from_x.ρ + msg_from_y.ρ) / (msg_from_x.ρ * msg_from_y.ρ))), 0)

    normalization_p = g_1 / ((1 - p) * g_0 + p * g_1)
    normalization_1_p = g_0 / ((1 - p) * g_0 + p * g_1)

    second_moment = (1 - p) * normalization_1_p * (gmean(msg_from_x)^2 + variance(msg_from_x)) + p * normalization_p * (μ_xy^2 + σ2_xy)

    μ_x = (1 - p) * normalization_1_p * gmean(msg_from_x) + p * normalization_p * μ_xy
    σ_x = sqrt(second_moment - μ_x^2)

    # UPDATE DISTRIBUTION OF X
    new_marginal_of_x = GaussianByMeanVariance(μ_x, σ_x^2)

    if isnan(new_marginal_of_x) || isinf(new_marginal_of_x)
        println(f)
        error("NAN/INF")
    end
    diff = absdiff(f.x, new_marginal_of_x)
    f.x.τ = new_marginal_of_x.τ
    f.x.ρ = new_marginal_of_x.ρ

    # UPDATE THE MESSAGE TO X
    new_msg_to_x = f.x / msg_from_x
    f.msg_to_x.τ = new_msg_to_x.τ
    f.msg_to_x.ρ = new_msg_to_x.ρ

    return diff
end

function update_msg_to_s!(f::BinaryGatedCopyFactor)
    msg_from_s = f.s / f.msg_to_s

    # UPDATE THE MESSAGE TO S
    msg_from_x = f.x / f.msg_to_x
    msg_from_y = f.y / f.msg_to_y

    if (msg_from_y.ρ == 0.0)
        new_msg_to_s = BinaryByProbability(0.0)
        f.msg_to_s.θ = new_msg_to_s.θ
    else
        μ_y = gmean(msg_from_y)
        σ_y = sqrt(variance(msg_from_y))
        μ_x = gmean(msg_from_x)
        σ_x = sqrt(variance(msg_from_x))

        p_0 = pdf(Normal(μ_y, σ_y), 0)
        p_1 = pdf(Normal(μ_y-μ_x, sqrt(σ_y^2 + σ_x^2)), 0)

        new_msg_to_s = Binary(log(p_1 / p_0))
        f.msg_to_s.θ = new_msg_to_s.θ
    end

    # UPDATE THE DISTRIBUTION OF S
    new_s = msg_from_s * f.msg_to_s
    f.s.θ = new_s.θ

    if isnan(f.s) || isinf(f.s)
        println(f)
        error("NAN/INF")
    end
end