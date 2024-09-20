################################################################################
# MODEL SAVING AND LOADING
#

function save_model(urgencies::Dict{UInt64, Gaussian}, filename::AbstractString)
    model_file = open(filename, "w")
    for (key, gaussian) in urgencies
        println(model_file, "$key $(mean(gaussian)) $(variance(gaussian))")
    end
    close(model_file)

    println()
    @info("Model saved!",
        filename=filename,
        file_size_in_mb=stat(filename).size / 1024^2,
        nr_of_features=length(urgencies)
    )
end

function load_model(filename::AbstractString)
    urgencies = Dict{UInt64, Gaussian}()

    model_file = open(filename, "r")
    for line in eachline(model_file)
        parts = split(line)
        urgencies[parse(UInt64, parts[1])] = GaussianByMeanVariance(parse(Float64, parts[2]), parse(Float64, parts[3]))
    end

    close(model_file)

    println()
    @info("Model loaded!",
        filename=filename,
        file_size_in_mb=stat(filename).size / 1024^2,
        nr_of_features=length(urgencies)
    )

    return urgencies
end
