using Random
using Plots
using StaticArrays

################################################################################
# HASH TABLE (stores the learned gaussians)
#

struct ValueTableEntry
    key::UInt64
    value::Gaussian
end

struct ValueTable
    table::Vector{Vector{ValueTableEntry}}
    no_bits::UInt64
end

function fibonacci_hash(key::UInt64, no_bits::UInt64)
    return (key * UInt64(11400714819323198485)) >> (64 - no_bits)
end

function ValueTable(;no_bits::Int64)
    table = Vector{Vector{ValueTableEntry}}(undef, 2^no_bits)
    return ValueTable(table, UInt64(no_bits))
end

function Base.setindex!(vt::ValueTable, value::Gaussian, key::UInt64)
    index = fibonacci_hash(key, vt.no_bits) + 1

    if !isassigned(vt.table, index)
        vt.table[index] = Vector{ValueTableEntry}()
    else 
        for i in eachindex(vt.table[index])
            if vt.table[index][i].key == key
                vt.table[index][i] = ValueTableEntry(key, value)
                return
            end
        end
    end

    push!(vt.table[index], ValueTableEntry(key, value))
end

function Base.getindex(vt::ValueTable, key::UInt64)
    index = fibonacci_hash(key, vt.no_bits) + 1

    if !isassigned(vt.table, index)
        return nothing
    end

    for i in eachindex(vt.table[index])
        if vt.table[index][i].key == key
            return vt.table[index][i].value
        end
    end

    return nothing
end

function Base.iterate(vt::ValueTable, state=(1, 0))
    outer_index, inner_index = state

    while outer_index <= length(vt.table)
        if isassigned(vt.table, outer_index)
            inner_index += 1

            if inner_index <= length(vt.table[outer_index])
                return (vt.table[outer_index][inner_index], (outer_index, inner_index))
            else
                inner_index = 0
            end 
        end

        outer_index += 1
    end

    return nothing

end

function Base.iterate(entry::ValueTableEntry, state=1)
    state == 1 && return (entry.key, 2)
    state == 2 && return (entry.value, 3)
    return nothing
end

function Base.length(vt::ValueTable)
    entries = 0
    for i in eachindex(vt.table)
        if isassigned(vt.table, i)
            entries += length(vt.table[i])
        end
    end

    return entries
end

function plot_hash_distribution(vt::ValueTable)
    values = [length(vt.table[i]) for i in eachindex(vt.table) if isassigned(vt.table, i)]
    plt = histogram(values, bins=100, label="Number of entries per bucket", xlabel="Number of entries", ylabel="Number of buckets")
    display(plt)
end

################################################################################
# ZOBRIST HASH TABLE (for move hashing)
#

struct ZobristValueTable
    src::SVector{64, UInt64}
    dst::SVector{64, UInt64}
    piece::SVector{15, UInt64}
    type::SVector{17, UInt64}
end

function ZobristValueTable()
    Random.seed!(12345)

    src = SVector{64, UInt64}([rand(UInt64) for _ in 1:64])
    dst = SVector{64, UInt64}([rand(UInt64) for _ in 1:64])
    piece = SVector{15, UInt64}([rand(UInt64) for _ in 1:15])
    type = SVector{17, UInt64}([rand(UInt64) for _ in 1:17])

    return ZobristValueTable(src, dst, piece, type)
end

const ZOBRIST_VALUE_TABLE = ZobristValueTable()

function move_to_hash(move)
    return ((UInt(move.src) << 10) | (UInt(move.dst) << 4) | UInt(move.type)) + 768
end

################################################################################
# MODEL SAVING AND LOADING
#

function save_model(model::ValueTable, filename::AbstractString)
    model_file = open(filename, "w")
    for (key, value) in model
        println(model_file, "$key $(gmean(value)) $(variance(value))")
    end
    close(model_file)

    println()
    @info("Model saved!",
        filename=filename,
        file_size_in_mb=stat(filename).size / 1024^2,
        nr_of_features=length(model)
    )
end

function load_model(filename::AbstractString)
    model = ValueTable(no_bits = 24)

    model_file = open(filename, "r")
    for line in eachline(model_file)
        key, mean, variance = split(line)
        model[parse(UInt64, key)] = GaussianByMeanVariance(parse(Float64, mean), parse(Float64, variance))
    end
    close(model_file)

    println()
    @info("Model loaded!",
        filename=filename,
        file_size_in_mb=stat(filename).size / 1024^2,
        nr_of_features=length(model)
    )

    return model
end
