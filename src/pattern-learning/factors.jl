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

function update!(f1::GaussianFactor, f2::GaussianFactor)
    update!(f1.x, f2.x)
    update!(f1.msg_to_x, f2.msg_to_x)
    update!(f1.prior, f2.prior)
end

function update_msg_to_x!(f::GaussianFactor)
    msg_from_x = f.x / f.msg_to_x
    
    # UPDATE THE MESSAGE TO X
    update!(f.msg_to_x, f.prior)

    # UPDATE THE DISTRIBUTION OF X
    new_marginal_of_x = msg_back * f.msg_to_x
    diff = absdiff(f.x, new_marginal_of_x)
    update!(f.x, new_marginal_of_x)
    
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

function update!(f1::GaussianMeanFactor, f2::GaussianMeanFactor)
    update!(f1.x, f2.x)
    update!(f1.y, f2.y)
    update!(f1.msg_to_x, f2.msg_to_x)
    update!(f1.msg_to_y, f2.msg_to_y)
    f1.beta_squared = f2.beta_squared
end

function update_msg_to_x!(f::GaussianMeanFactor)
    msg_from_x = f.x / f.msg_to_x
    msg_from_y = f.y / f.msg_to_y

    # UPDATE THE MESSAGE TO X
    if (isdirac(msg_from_y))
        update!(f.msg_to_x, GaussianByMeanVariance(mean(msg_from_y), beta_squared))
    elseif (isuniform(msg_from_y))
        update!(f.msg_to_x, GaussianUniform())
    else
        c = 1.0 / (1.0 + f.beta_squared * msg_from_y.ρ)
        update!(f.msg_to_x, GaussianByMeanPrecision(c * msg_from_y.τ, c * msg_from_y.ρ))
    end

    # UPDATE THE DISTRIBUTION OF X
    new_marginal_of_x = msg_from_x * f.msg_to_x
    diff = absdiff(f.x, new_marginal_of_x)
    update!(f.x, new_marginal_of_x)

    return diff
end

function update_msg_to_y!(f::GaussianMeanFactor)
    msg_from_y = f.y / f.msg_to_y
    msg_from_x = f.x / f.msg_to_x

    # UPDATE THE MESSAGE TO Y
    if (isdirac(msg_from_x))
        update!(f.msg_to_y, GaussianByMeanVariance(mean(msg_from_x), beta_squared))
    elseif (isuniform(msg_from_x))
        update!(f.msg_to_y, GaussianUniform())
    else
        c = 1.0 / (1.0 + f.beta_squared * msg_from_x.ρ)
        update!(f.msg_to_y, GaussianByMeanPrecision(c * msg_from_x.τ, c * msg_from_x.ρ))
    end

    # UPDATE THE DISTRIBUTION OF Y
    new_marginal_of_y = msg_from_y * f.msg_to_y
    diff = absdiff(f.y, new_marginal_of_y)
    update!(f.y, new_marginal_of_y)

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

function update!(f1::SumFactor, f2::SumFactor)
    for i in eachindex(f1.summands)
        update!(f1.summands[i], f2.summands[i])
        update!(f1.msg_to_summands[i], f2.msg_to_summands[i])
    end

    update!(f1.sum, f2.sum)
    update!(f1.msg_to_sum, f2.msg_to_sum)
end

function update_msg_to_sum!(f::SumFactor)
    msg_from_sum = f.sum / f.msg_to_sum
    
    # PRECISION & PRECISION MEAN OF MSG TO SUM
    incoming_msgs = [f.summands[i] / f.msg_to_summands[i] for i in eachindex(f.summands)]

    μ = 0.0
    σ2 = 0.0
    for msg in incoming_msgs
        if isuniform(msg)
            error("Uniform message in summands of sum factor")
        end
        μ += mean(msg)
        σ2 += variance(msg)
    end
    precision = 1.0 / σ2
    precision_mean = precision * μ

    # UPDATE THE MESSAGE TO SUM
    update!(f.msg_to_sum, GaussianByMeanPrecision(precision_mean, precision))

    # UPDATE THE DISTRIBUTION OF SUM
    updated_sum = msg_from_sum * f.msg_to_sum
    diff = absdiff(f.sum, updated_sum)
    update!(f.sum, updated_sum)

    return diff
end


function update_msg_to_summands!(f::SumFactor)
    inc_msg_from_sum = f.sum / f.msg_to_sum
    inc_msgs_from_summands = [f.summands[j] / f.msg_to_summands[j] for j in eachindex(f.summands)]

    var_sum = 0.0
    mean_sum = 0.0
    for msg in inc_msgs_from_summands
        if isuniform(msg)
            error("Uniform message in summands of sum factor")
        end

        var_sum += variance(msg)
        mean_sum += mean(msg)
    end

    max_diff = 0.0

    if isuniform(inc_msg_from_sum)
        for i in eachindex(f.summands)
            update!(f.msg_to_summands[i], GaussianUniform())

            new_marginal_of_summand = inc_msgs_from_summands[i] * f.msg_to_summands[i]
            diff = absdiff(f.summands[i], new_marginal_of_summand)
            max_diff = max(max_diff, diff)
            update!(f.summands[i], new_marginal_of_summand)
        end
    else
        a = mean(inc_msg_from_sum) - mean_sum
        b = variance(inc_msg_from_sum) + var_sum
        for i in eachindex(f.summands)
            update!(f.msg_to_summands[i], GaussianByMeanVariance(a + mean(inc_msgs_from_summands[i]), b - variance(inc_msgs_from_summands[i])))

            new_marginal_of_summand = inc_msgs_from_summands[i] * f.msg_to_summands[i]
            diff = absdiff(f.summands[i], new_marginal_of_summand)
            max_diff = max(max_diff, diff)
            update!(f.summands[i], new_marginal_of_summand)
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

function update!(f1::DifferenceFactor, f2::DifferenceFactor)
    update!(f1.x, f2.x)
    update!(f1.y, f2.y)
    update!(f1.z, f2.z)
    update!(f1.msg_to_x, f2.msg_to_x)
    update!(f1.msg_to_y, f2.msg_to_y)
    update!(f1.msg_to_z, f2.msg_to_z)
end

function update_msg_to_x!(f::DifferenceFactor)
    msg_from_x = f.x / f.msg_to_x

    # PRECISION & PRECISION MEAN OF MSG TO X
    msg_from_y = f.y / f.msg_to_y
    msg_from_z = f.z / f.msg_to_z

    if isuniform(msg_from_y) && isuniform(msg_from_z)
        error("Difference of two uniform distributions is undefined")
    end

    if isuniform(msg_from_y) || isuniform(msg_from_z)
        update!(f.msg_to_x, GaussianUniform())
    elseif isdirac(msg_from_y) && isdirac(msg_from_z)
        update!(f.msg_to_x, GaussianDirac(mean(msg_from_z) + mean(msg_from_y)))
    else
        update!(f.msg_to_x, GaussianByMeanVariance(mean(msg_from_z) + mean(msg_from_y), variance(msg_from_z) + variance(msg_from_y)))
    end

    # UPDATE THE DISTRIBUTION OF X
    new_marginal_of_x = msg_from_x * f.msg_to_x
    diff = absdiff(f.x, new_marginal_of_x)
    update!(f.x, new_marginal_of_x)

    return diff
end

function update_msg_to_y!(f::DifferenceFactor)
    msg_from_y = f.y / f.msg_to_y

    # PRECISION & PRECISION MEAN OF MSG TO Y
    msg_from_x = f.x / f.msg_to_x
    msg_from_z = f.z / f.msg_to_z

    if isuniform(msg_from_x) && isuniform(msg_from_z)
        error("Difference of two uniform distributions is undefined")
    end

    if isuniform(msg_from_x) || isuniform(msg_from_z)
        update!(f.msg_to_y, GaussianUniform())
    elseif isdirac(msg_from_x) && isdirac(msg_from_z)
        update!(f.msg_to_y, GaussianDirac(mean(msg_from_x) - mean(msg_from_z)))
    else
        update!(f.msg_to_y, GaussianByMeanVariance(mean(msg_from_x) - mean(msg_from_z), variance(msg_from_x) + variance(msg_from_z)))
    end

    # UPDATE THE DISTRIBUTION OF Y
    new_marginal_of_y = msg_from_y * f.msg_to_y
    diff = absdiff(f.y, new_marginal_of_y)
    update!(f.y, new_marginal_of_y)

    return diff
end

function update_msg_to_z!(f::DifferenceFactor)
    msg_from_z = f.z / f.msg_to_z

    # PRECISION & PRECISION MEAN OF MSG TO Z
    msg_from_x = f.x / f.msg_to_x
    msg_from_y = f.y / f.msg_to_y

    if isuniform(msg_from_x) && isuniform(msg_from_y)
        error("Difference of two uniform distributions is undefined")
    end

    if isuniform(msg_from_x) || isuniform(msg_from_y)
        update!(f.msg_to_z, GaussianUniform())
    elseif isdirac(msg_from_x) && isdirac(msg_from_y)
        update!(f.msg_to_z, GaussianDirac(mean(msg_from_x) - mean(msg_from_y)))
    else
        update!(f.msg_to_z, GaussianByMeanVariance(mean(msg_from_x) - mean(msg_from_y), variance(msg_from_x) + variance(msg_from_y)))
    end

    # UPDATE THE DISTRIBUTION OF Z
    new_marginal_of_z = msg_from_z * f.msg_to_z
    diff = absdiff(f.z, new_marginal_of_z)
    update!(f.z, new_marginal_of_z)

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

function update!(f1::GreaterThanFactor, f2::GreaterThanFactor)
    update!(f1.x, f2.x)
    update!(f1.msg_to_x, f2.msg_to_x)
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
    if pdf(normal, t) < 1e-10
        return (t < 0.0) ? 1.0 : 0.0
    else
        return v(t) * (v(t) + t)
    end
end

function update_msg_to_x!(f::GreaterThanFactor)
    msg_from_x = f.x / f.msg_to_x
    
    if isuniform(msg_from_x) 
        @show f.x
        @show f.msg_to_x
        error("Uniform message in greater than factor is undefined")
    end

    if isdirac(msg_from_x) && (msg_from_x.τ <= 0.0)
        error("Dirac delta with negative mean in greater than factor is undefined")
    end

    if isdirac(msg_from_x)
        new_marginal_of_x = GaussianDirac(mean(msg_from_x))
    else
        a = msg_from_x.τ / sqrt(msg_from_x.ρ)

        if w(a) == 1.0
            new_marginal_of_x = GaussianDirac(0.0)
        else
            precision = msg_from_x.ρ / (1 - w(a))
            precision_mean = (msg_from_x.τ + sqrt(msg_from_x.ρ) * v(a)) / (1 - w(a))

            new_marginal_of_x = GaussianByMeanPrecision(precision_mean, precision)
        end
    end

    diff = absdiff(f.x, new_marginal_of_x)
    update!(f.x, new_marginal_of_x)

    # UPDATE THE MESSAGE TO X
    update!(f.msg_to_x, f.x / msg_from_x)

    return diff
end

struct SignConsistencyFactor <: Factor
    x::Gaussian
    s::Binary
    msg_to_x::Gaussian
    msg_to_s::Binary
end

function Base.show(io::IO, f::SignConsistencyFactor)
    println(io, "SIGN CONSISTENCY FACTOR")
    println(io, "X: $(f.x)")
    println(io, "S: $(f.s)")
    println(io, "Msg to X: $(f.msg_to_x)")
    println(io, "Msg to S: $(f.msg_to_s)")
end

function SignConsistencyFactor(x::Gaussian, s::Binary)
    error("Not implemented")
    return SignConsistencyFactor(x, s, GaussianUniform(), BinaryUniform())
end

function update!(f1::SignConsistencyFactor, f2::SignConsistencyFactor)
    error("Not implemented")
    update!(f1.x, f2.x)
    update!(f1.s, f2.s)
    update!(f1.msg_to_x, f2.msg_to_x)
    update!(f1.msg_to_s, f2.msg_to_s)
end

function v(t, p)
    error("Not implemented")
    normal = Normal()
    d = pdf(normal, t)
    c = cdf(normal, t)
    return ((1-2*p) * d) / ((1-2*p) * c + p)
end

function w(t, p)
    error("Not implemented")
    normal = Normal()
    return v(t, p) * (v(t, p) + t)
end

function update_msg_to_s!(f::SignConsistencyFactor)
    error("Not implemented")
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
    error("Not implemented")
    msg_from_x = f.x / f.msg_to_x
    msg_from_s = f.s / f.msg_to_s
    
    # PRECISION & PRECISION MEAN OF TRUNCATED GAUSSIAN (X)
    precision = 0.0
    precision_mean = 0.0

    if msg_from_x.ρ != 0.0
        c = -(msg_from_x.τ / sqrt(msg_from_x.ρ))
        p = mean(msg_from_s)
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
    print(io, "\033[33m")
    println(io, "X: $(f.x)")
    println(io, "Y: $(f.y)")
    println(io, "S: $(f.s)")
    print(io, "\033[32m")
    println(io, "Msg to X: $(f.msg_to_x)")
    println(io, "Msg to Y: $(f.msg_to_y)")
    println(io, "Msg to S: $(f.msg_to_s)")
    print(io, "\033[0m")
end

function BinaryGatedCopyFactor(x::Gaussian, y::Gaussian, s::Binary)
    return BinaryGatedCopyFactor(x, y, s, GaussianUniform(), GaussianUniform(), BinaryUniform())
end

function update!(f1::BinaryGatedCopyFactor, f2::BinaryGatedCopyFactor; exclude_s=false)
    update!(f1.x, f2.x)
    update!(f1.y, f2.y)
    if !exclude_s
        update!(f1.s, f2.s)
    end
    update!(f1.msg_to_x, f2.msg_to_x)
    update!(f1.msg_to_y, f2.msg_to_y)
    update!(f1.msg_to_s, f2.msg_to_s)
end

function z_function(μ_x, μ_y, σ2_x, σ2_y)
    return (pdf(Normal(μ_y, sqrt(σ2_y)), 0)) / (pdf(Normal(μ_y, sqrt(σ2_x + σ2_y)), μ_x))
end

function q_function(μ_x, μ_y, σ2_x, σ2_y, p)
    z = z_function(μ_x, μ_y, σ2_x, σ2_y)

    return p / ((1-p) * z + p)
end

function update_msg_to_y!(f::BinaryGatedCopyFactor)
    msg_from_y = f.y / f.msg_to_y
    msg_from_x = f.x / f.msg_to_x
    msg_from_s = f.s / f.msg_to_s
    p = mean(msg_from_s)
    
    ############################################################
    # SPECIAL CASES
    if p == 1.0
        # UPDATE THE MESSAGE TO Y
        update!(f.msg_to_y, msg_from_x)

        # UPDATE THE DISTRIBUTION OF Y
        new_marginal_of_y = msg_from_y * f.msg_to_y
        diff = absdiff(f.y, new_marginal_of_y)
        update!(f.y, new_marginal_of_y)

        return diff
    elseif p == 0.0
        # UPDATE THE MESSAGE TO Y
        update!(f.msg_to_y, GaussianDirac(0.0))

        # UPDATE THE DISTRIBUTION OF Y
        new_marginal_of_y = msg_from_y * f.msg_to_y
        diff = absdiff(f.y, new_marginal_of_y)
        update!(f.y, new_marginal_of_y)

        return diff
    end

    ############################################################
    # GENERAL CASE: 0.0 < p < 1.0
    if isuniform(msg_from_y)
        if isuniform(msg_from_x)
            error("Uniform message in y and uniform in x is undefined in binary gated copy factor")
        end

        μ_x = mean(msg_from_x)
        σ2_x = variance(msg_from_x)

        μ_xy = μ_x
        σ2_xy = σ2_x    # possibly 0.0, if x is dirac delta
        
        q = p           # q_function(μ_x, μ_y, σ2_x -> 0, σ2_y -> inf, p)

        new_mean = q * μ_xy
        new_variance = q * (σ2_xy + q * (1 - q) * μ_xy^2)

        new_marginal_of_y = GaussianByMeanVariance(new_mean, new_variance)
    
    elseif isdirac(msg_from_y)
        if isuniform(msg_from_x)
            error("Dirac delta in y and uniform in x is undefined in binary gated copy factor")
        end

        μ_x = mean(msg_from_x)
        μ_y = mean(msg_from_y)

        if isdirac(msg_from_x) && (μ_y != 0.0 && μ_y != μ_x)
            error("Dirac deltas with different mean in x and y (or non-zero mean in y) is undefined in binary gated copy factor")
        end

        new_marginal_of_y = GaussianDirac(μ_y)
    else
        if isuniform(msg_from_x)
            new_marginal_of_y = GaussianDirac(0.0)
        else
            μ_x = mean(msg_from_x)
            σ2_x = variance(msg_from_x)
            μ_y = mean(msg_from_y)
            σ2_y = variance(msg_from_y)


            μ_xy = (σ2_x * μ_y + σ2_y * μ_x) / (σ2_x + σ2_y)
            σ2_xy = (σ2_x * σ2_y) / (σ2_x + σ2_y)

            q = q_function(μ_x, μ_y, σ2_x, σ2_y, p)

            new_mean = q * μ_xy
            new_variance = q * (σ2_xy + q * (1 - q) * μ_xy^2)

            new_marginal_of_y = GaussianByMeanVariance(new_mean, new_variance)
        end
    end

    # UPDATE THE DISTRIBUTION OF Y
    diff = absdiff(f.y, new_marginal_of_y)
    update!(f.y, new_marginal_of_y)

    # UPDATE THE MESSAGE TO Y
    unsafe_update!(f.msg_to_y, unsafe_division(f.y, msg_from_y))

    return diff
end

function update_msg_to_x!(f::BinaryGatedCopyFactor)
    msg_from_x = f.x / f.msg_to_x
    msg_from_y = f.y / f.msg_to_y
    msg_from_s = f.s / f.msg_to_s
    p = mean(msg_from_s)

    
    ############################################################
    # SPECIAL CASES
    if p == 1.0
        # UPDATE THE MESSAGE TO X
        update!(f.msg_to_x, msg_from_y)

        # UPDATE THE DISTRIBUTION OF X
        new_marginal_of_x = msg_from_x * f.msg_to_x
        diff = absdiff(f.x, new_marginal_of_x)
        update!(f.x, new_marginal_of_x)

        return diff
    elseif p == 0.0
        # UPDATE THE MESSAGE TO X
        update!(f.msg_to_x, GaussianUniform())

        # UPDATE THE DISTRIBUTION OF X
        new_marginal_of_x = msg_from_x * f.msg_to_x
        diff = absdiff(f.x, new_marginal_of_x)
        update!(f.x, new_marginal_of_x)

        return diff
    end

    ############################################################
    # GENERAL CASE: 0.0 < p < 1.0
    if isuniform(msg_from_y)
        if isuniform(msg_from_x)
            error("Uniform message in y and uniform in x is undefined in binary gated copy factor")
        end

        # LONG WAY
        # μ_xy = μ_x
        # σ2_xy = σ2_x    # possibly 0.0, if x is dirac delta
        
        # q = p           # q_function(μ_x, μ_y, σ2_x -> 0, σ2_y -> inf, p)

        # new_mean = (1 - q) * μ_x + q * μ_xy 
        # new_variance = (1 - q) * σ2_x + q * σ2_xy + q * (1 - q) * (μ_x - μ_xy)^2

        # new_marginal_of_x = GaussianByMeanVariance(new_mean, new_variance)

        # SHORT WAY
        μ_x = mean(msg_from_x)
        σ2_x = variance(msg_from_x)

        new_marginal_of_x = GaussianByMeanVariance(μ_x, σ2_x)

    elseif isdirac(msg_from_y)
        if isuniform(msg_from_x)
            error("Dirac delta in y and uniform in x is undefined in binary gated copy factor")
        end

        μ_x = mean(msg_from_x)
        μ_y = mean(msg_from_y)

        if isdirac(msg_from_x) && (μ_y != 0.0 && μ_y != μ_x)
            error("Dirac deltas with different mean in x and y (or non-zero mean in y) is undefined in binary gated copy factor")
        end

        new_marginal_of_x = GaussianDirac(μ_y)
    else
        if isuniform(msg_from_x)
            new_marginal_of_x = GaussianUniform()
        else
            μ_x = mean(msg_from_x)
            σ2_x = variance(msg_from_x)
            μ_y = mean(msg_from_y)
            σ2_y = variance(msg_from_y)

            μ_xy = (σ2_x * μ_y + σ2_y * μ_x) / (σ2_x + σ2_y)
            σ2_xy = (σ2_x * σ2_y) / (σ2_x + σ2_y)

            q = q_function(μ_x, μ_y, σ2_x, σ2_y, p)

            new_mean = (1 - q) * μ_x + q * μ_xy
            new_variance = (1 - q) * σ2_x + q * σ2_xy + q * (1 - q) * (μ_x - μ_xy)^2
            
            new_marginal_of_x = GaussianByMeanVariance(new_mean, new_variance)
        end
    end

    # UPDATE THE DISTRIBUTION OF X
    diff = absdiff(f.x, new_marginal_of_x)
    update!(f.x, new_marginal_of_x)

    # UPDATE THE MESSAGE TO X
    unsafe_update!(f.msg_to_x, unsafe_division(f.x, msg_from_x))

    return diff
end

function update_msg_to_s!(f::BinaryGatedCopyFactor)
    msg_from_s = f.s / f.msg_to_s
    msg_from_x = f.x / f.msg_to_x
    msg_from_y = f.y / f.msg_to_y

    if isuniform(msg_from_y)
        z = 1.0

    elseif isdirac(msg_from_y)
        if isdirac(msg_from_x)
            if mean(msg_from_y) != 0
                if mean(msg_from_x) == mean(msg_from_y)
                    z = 0.0
                else
                    error("Dirac delta in x and dirac delta in y with different means is undefined in binary gated copy factor")
                end
            else
                if mean(msg_from_x) == 0
                    error("Dirac delta in x and dirac delta in y is undefined in binary gated copy factor")
                else
                    z = Inf
                end
            end
        elseif isuniform(msg_from_x)
            if mean(msg_from_y) == 0
                z = Inf
            else
                error("Uniform message in x and dirac delta in y is undefined in binary gated copy factor")
            end
        else
            if mean(msg_from_y) == 0
                z = Inf
            else
                z = 0.0
            end
        end

    else
        if isuniform(msg_from_x)
            z = Inf
        elseif isdirac(msg_from_x)
            if mean(msg_from_x) == mean(msg_from_y)
                z = 0.0
            else
                z = Inf
            end
        else
            z = z_function(mean(msg_from_x), mean(msg_from_y), variance(msg_from_x), variance(msg_from_y))
        end
    end

    new_prob = 1 / (1 + z)

    # UPDATE THE MESSAGE TO S
    update!(f.msg_to_s, BinaryByProbability(new_prob))

    # UPDATE THE DISTRIBUTION OF S
    new_s = f.msg_to_s * msg_from_s
    diff = kl_divergence(f.s, new_s) 
    update!(f.s, new_s)

    return diff
end
