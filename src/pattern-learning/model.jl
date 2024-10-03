using Serialization

################################################################################
# MODEL SAVING AND LOADING
#

function save_model(urgencies::Dict{UInt64, Gaussian}, filename::AbstractString)
    open(filename, "w") do io
        serialize(io, urgencies)
    end

    println()
    @info("Model saved!",
        filename=filename,
        file_size_in_mb=stat(filename).size / 1024^2,
        nr_of_features=length(urgencies)
    )
end

function load_model(filename::AbstractString)
    urgencies::Dict{UInt64, Gaussian} = deserialize(filename)

    println()
    @info("Model loaded!",
        filename=filename,
        file_size_in_mb=stat(filename).size / 1024^2,
        nr_of_features=length(urgencies)
    )

    return urgencies
end
