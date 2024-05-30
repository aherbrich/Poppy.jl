using Random
using Plots
using StaticArrays

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

struct ValueTableEntry
    key::UInt64
    value::Gaussian
end

struct ValueTable
    table::Vector{Vector{ValueTableEntry}}
    zobrist_table::ZobristValueTable
    no_bits::UInt64
end

function fibonacci_hash(key::UInt64, no_bits::UInt64)
    return (key * UInt64(11400714819323198485)) >> (64 - no_bits)
end

function ValueTable(;no_bits::Int64)
    table = Vector{Vector{ValueTableEntry}}(undef, 2^no_bits)
    zobrist_table = ZobristValueTable()
    return ValueTable(table, zobrist_table, UInt64(no_bits))
end

function Base.setindex!(vt::ValueTable, value::Gaussian, key::UInt64)
    index = fibonacci_hash(key, vt.no_bits) + 1

    if !isassigned(vt.table, index)
        vt.table[index] = Vector{ValueTableEntry}()
    else 
        for i in eachindex(vt.table[index])
            if vt.table[index][i].key == key
                vt.table[index][i].value = value
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

function plot_hash_distribution(vt::ValueTable)
    values = [length(vt.table[i]) for i in eachindex(vt.table) if isassigned(vt.table, i)]
    plt = histogram(values, bins=100, label="Number of entries per bucket", xlabel="Number of entries", ylabel="Number of buckets")
    display(plt)
end

const ZOBRIST_VALUE_TABLE = ZobristValueTable()

function move_to_hash(move)
    hash = UInt64(0)
    hash = hash ⊻ ZOBRIST_VALUE_TABLE.type[move.type + 1]
    hash = hash ⊻ ZOBRIST_VALUE_TABLE.src[move.src + 1]
    hash = hash ⊻ ZOBRIST_VALUE_TABLE.dst[move.dst + 1]

    return hash
end