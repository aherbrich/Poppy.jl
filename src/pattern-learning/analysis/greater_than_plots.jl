
using Plots
using Distributions
using Measures
using LaTeXStrings

function plot_greater_than_good_approximation()
    outgoing_μ = 1.7
    outgoing_σ_2 = 1.0
    outgoing_msg = GaussianByMeanVariance(outgoing_μ, outgoing_σ_2) 

    function true_incoming_msg(x)
        return (x > 0.0) ? 1.0 : 0.0
    end

    function true_posterior(x)
        normalization = 1 / (1 - cdf(Normal(outgoing_μ, sqrt(outgoing_σ_2)), 0.0))
        return pdf(Normal(outgoing_μ, sqrt(outgoing_σ_2)), x) * true_incoming_msg(x) * normalization
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

    a = outgoing_msg.τ / sqrt(outgoing_msg.ρ)

    precision = outgoing_msg.ρ / (1 - w(a))
    precision_mean = (outgoing_msg.τ + sqrt(outgoing_msg.ρ) * v(a)) / (1 - w(a))

    new_marginal_of_x = GaussianByMeanPrecision(precision_mean, precision)

    approximate_incoming_msg = new_marginal_of_x / outgoing_msg

    function approximate_posterior(x)
        return pdf(Normal(mean(new_marginal_of_x), sqrt(variance(new_marginal_of_x))), x)
    end

    function approximate_incremental(x)
        return pdf(Normal(mean(approximate_incoming_msg), sqrt(variance(approximate_incoming_msg))), x)
    end


    plt = plot(dpi=500, fontfamily="serif-roman", xlabel="x", ylabel="p(x)", legend=:topleft, tickfontsize=13, guidefontsize=13, legendfontsize=13, titlefontsize=17, top_margin=8mm, bottom_margin=8mm, left_margin=4mm, right_margin=4mm)
    plot!(x->pdf(Normal(outgoing_μ, sqrt(outgoing_σ_2)), x), -5.0, 5.0, color=:green, lw=2, label=L"m_{X\rightarrow f}(x)")

    plot!(x->true_incoming_msg(x), -5.0, 5.0, lw=2, color=:blue, label=L"m_{f\rightarrow X}(x)")
    plot!(x->approximate_incremental(x), -5.0, 5.0, color=:blue, lw=2, label=L"\hat{m}_{f\rightarrow X}(x)", style=:dot)

    plot!(x->true_posterior(x), -5.0, 5.0, color=:red, lw=2, label=L"p(x)")
    plot!(x->approximate_posterior(x), -5.0, 5.0, color=:red, lw=2, label=L"\hat{p}(x)", style=:dot)


    savefig(plt, "gaussian_good_approximation.png")
    run(`open gaussian_good_approximation.png`)
end

function plot_greater_than_poor_approximation()
    outgoing_μ = -2.0
    outgoing_σ_2 = 1.0
    outgoing_msg = GaussianByMeanVariance(outgoing_μ, outgoing_σ_2) 

    function true_incoming_msg(x)
        return (x > 0.0) ? 1.0 : 0.0
    end

    function true_posterior(x)
        normalization = 1 / (1 - cdf(Normal(outgoing_μ, sqrt(outgoing_σ_2)), 0.0))
        return pdf(Normal(outgoing_μ, sqrt(outgoing_σ_2)), x) * true_incoming_msg(x) * normalization
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

    a = outgoing_msg.τ / sqrt(outgoing_msg.ρ)

    precision = outgoing_msg.ρ / (1 - w(a))
    precision_mean = (outgoing_msg.τ + sqrt(outgoing_msg.ρ) * v(a)) / (1 - w(a))

    new_marginal_of_x = GaussianByMeanPrecision(precision_mean, precision)

    approximate_incoming_msg = new_marginal_of_x / outgoing_msg

    function approximate_posterior(x)
        return pdf(Normal(mean(new_marginal_of_x), sqrt(variance(new_marginal_of_x))), x)
    end

    function approximate_incremental(x)
        return pdf(Normal(mean(approximate_incoming_msg), sqrt(variance(approximate_incoming_msg))), x)
    end


    plt = plot(dpi=500, fontfamily="serif-roman", xlabel="x", ylabel="p(x)", legend=:topleft, tickfontsize=13, guidefontsize=13, legendfontsize=13, titlefontsize=17, top_margin=8mm, bottom_margin=8mm, left_margin=4mm, right_margin=4mm)
    plot!(x->pdf(Normal(outgoing_μ, sqrt(outgoing_σ_2)), x), -5.0, 5.0, color=:green, lw=2, label=L"m_{X\rightarrow f}(x)")

    plot!(x->true_incoming_msg(x), -5.0, 5.0, lw=2, color=:blue, label=L"m_{f\rightarrow X}(x)")
    plot!(x->approximate_incremental(x), -5.0, 5.0, color=:blue, lw=2, label=L"\hat{m}_{f\rightarrow X}(x)", style=:dot)

    plot!(x->true_posterior(x), -5.0, 5.0, color=:red, lw=2, label=L"p(x)")
    plot!(x->approximate_posterior(x), -5.0, 5.0, color=:red, lw=2, label=L"\hat{p}(x)", style=:dot)


    savefig(plt, "gaussian_poor_approximation.png")
    run(`open gaussian_poor_approximation.png`)
end