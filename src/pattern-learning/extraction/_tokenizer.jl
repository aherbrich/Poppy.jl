using DataStructures
using Plots

function get_pair_frequency(boards::Vector{Vector{Int}})
    token_pairs = Dict{Tuple{Int, Int}, Int}()
    for board in boards
        # iterate over all token pairs 1,2; 2,3; 3,4; ...
        for i in 1:(length(board) - 1)
            pair = (board[i], board[i + 1])
            token_pairs[pair] = get(token_pairs, pair, 0) + 1
        end
    end
    return token_pairs
end

function merge(boards::Vector{Vector{Int}}, max_pair::Tuple{Int, Int}, new_token_id::Int)
    for board in boards
        i = 1
        while i < length(board)
            if (board[i], board[i + 1]) == max_pair
                board[i] = new_token_id
                splice!(board, i + 1)
            end
            i += 1
        end
    end
end

function dump_dict(dict::AbstractDict, path::String)
    open(path, "w") do file
        for (key, value) in dict
            println(file, key, " -> ", value)
        end
    end
end

function load_encode_dict(path::String)
    encode_dict = OrderedDict{Tuple{Int, Int}, Int}()
    open(path) do file
        for line in eachline(file)
            parts = split(line, " -> ")
            
            key_parts = split(parts[1], ", ")
            key_parts .= strip.(key_parts, ['(', ')'])
            key_parts = parse.(Int, key_parts)

            value = parse(Int, parts[2])
            encode_dict[(key_parts[1], key_parts[2])] = value
        end
    end
    return encode_dict
end

function load_decode_dict(path::String)
    decode_dict = OrderedDict{Int, Tuple{Int, Int}}()
    open(path) do file
        for line in eachline(file)
            parts = split(line, " -> ")
            key = parse(Int, parts[1])
            
            value_parts = split(parts[2], ", ")
            value_parts .= strip.(value_parts, ['(', ')'])
            value_parts = parse.(Int, value_parts)

            decode_dict[key] = (value_parts[1], value_parts[2])
        end
    end
    return decode_dict
end

function generate_translation_dict(decode_dict::OrderedDict{Int, Tuple{Int, Int}})
    vocab = Dict{Int, Vector{Int}}()
    for i in 1:960
        vocab[i-1] = [i-1]
    end

    for (key, value) in decode_dict
        vocab[key] = vcat(vocab[value[1]], vocab[value[2]])
    end

    return vocab
end

function decode(input::Vector{Int}, translation_dict::Dict{Int, Vector{Int}})
    output = Vector{Int}()
    for token in input
        output = vcat(output, translation_dict[token])
    end

    return output
end

function encode(input::Vector{Int}, encode_dict::OrderedDict{Tuple{Int, Int}, Int})
    output = copy(input)

    while true
        token_pairs = get_pair_frequency([output])

        # find the token pair which has the lowest token id in encode dict
        min_pair = reduce((x, y) -> get(encode_dict, x, 100000) < get(encode_dict, y, 100000) ? x : y, keys(token_pairs))

        # if the token pair is not in the encode dict
        # i.e. 'get' triggered default value 100000 in all cases
        # then we are done
        if !haskey(encode_dict, min_pair)
            break
        end

        # else replace all occurrences of the min pair with the new token id
        merge([output], min_pair, encode_dict[min_pair])

        if length(output) == 1
            break
        end
    end

    return output
end

function tokenize(path::String; path_encode_dict::String="", path_decode_dict::String="")
    # read file into a data structure (list of lists)
    # where each line in the file corresponds to a list of integers
    text = Vector{Vector{Int}}()

    println("Reading file ", path)
    open(path) do file
        for line in eachline(file)
            # split line into words and interpret them as integers
            tokens = map(x -> parse(Int, x), split(line))
            push!(text, tokens)
        end
    end
    println("Read ", length(text), " lines")

    # load the encode and decode dictionaries
    encode_dict = (path_encode_dict == "") ? OrderedDict{Tuple{Int, Int}, Int}() : load_encode_dict(path_encode_dict)
    decode_dict = (path_decode_dict == "") ? OrderedDict{Int, Tuple{Int, Int}}() : load_decode_dict(path_decode_dict)

    if length(encode_dict) != length(decode_dict)
        println("Encode and decode dictionaries have different lengths")
        return
    end

    # extract new tokens by the byte pair encoding algorithm 
    nr_of_base_tokens = 960 + length(decode_dict)
    vocab_size = 65536
    number_of_merges = vocab_size - nr_of_base_tokens

    if number_of_merges <= 0
        println("No merges necessary, vocab size is already reached")
        return encode_dict, decode_dict
    end

    if length(encode_dict) > 0
        println("Preprocessing: encoding text with provided tokens")
        text = map(x -> encode(x, encode_dict), text)
    end
    
    for i in 1:number_of_merges
        println("Iteration: $i/$number_of_merges")

        # count the frequency of all token pairs
        # i.e. token pairs at indices (1,2), (2,3), (3,4), ... 
        token_pairs = get_pair_frequency(text)
        
        # find pair with highest frequency
        max_pair = reduce((x, y) -> token_pairs[x] > token_pairs[y] ? x : y, keys(token_pairs))
        
        # calculate the new token id
        new_token_id = nr_of_base_tokens + i - 1

        # save the pair -> new token and new token -> pair mappings
        encode_dict[max_pair] = new_token_id
        decode_dict[new_token_id] = max_pair

        # replace all occurrences of the max pair with the new token id
        merge(text, max_pair, new_token_id)
        # merge_tokens(text, max_pair, new_token_id)
        println("   Replaced all occurrences of the most frequent pair", max_pair, " with new token ", new_token_id)

        # dump the mappings to disk
        if i % 500 == 0
            println("   Dumping dictionaries of size ", length(encode_dict))
            dump_dict(encode_dict, "/Users/aherbrich/src/Poppy/data/training/processed/encode_dict.txt")
            dump_dict(decode_dict, "/Users/aherbrich/src/Poppy/data/training/processed/decode_dict.txt")
        end
    end

    # dump the final mappings to disk
    dump_dict(encode_dict, "/Users/aherbrich/src/Poppy/data/training/processed/encode_dict.txt")
    dump_dict(decode_dict, "/Users/aherbrich/src/Poppy/data/training/processed/decode_dict.txt")

    return encode_dict, decode_dict
end

# tokenize("/Users/aherbrich/src/Poppy/data/training/processed/tokenbase.txt"; path_encode_dict="/Users/aherbrich/src/Poppy/data/training/processed/encode_dict.txt", path_decode_dict="/Users/aherbrich/src/Poppy/data/training/processed/decode_dict.txt")


# function test_tokenizer(path::String)
#     encode_dict = load_encode_dict("/Users/aherbrich/src/Poppy/data/training/processed/encode_dict.txt")
#     decode_dict = load_decode_dict("/Users/aherbrich/src/Poppy/data/training/processed/decode_dict.txt")
#     translation_dict = generate_translation_dict(decode_dict)

#     text = Vector{Vector{Int}}()

#     println("Reading file ", path)
#     open("/Users/aherbrich/src/Poppy/data/training/processed/tokenbase.txt") do file
#         for line in eachline(file)
#             # split line into words and interpret them as integers
#             tokens = map(x -> parse(Int, x), split(line))
#             push!(text, tokens)
#         end
#     end
#     nr_of_lines = length(text)

#     encoded_length = Vector{Int}()
#     println("Read ", nr_of_lines, " lines")
#     for (i, line) in enumerate(text)
#         encoded = encode(line, encode_dict)
#         push!(encoded_length, length(encoded))
#         decoded = decode(encoded, translation_dict)

#         if i % 10000 == 0
#             println("Compression factor: ", (length(encoded_length) * 64) / sum(encoded_length))
#             println("Plotting compression", i)
#             plt = histogram(encoded_length, label="Encoded length", title="Encoded length distribution")
#             display(plt)
#             readline(stdin)
#         end

#         if line != decoded
#             println("Error in line ", i)
#             break
#         end
#     end
# end

# test_tokenizer("/Users/aherbrich/src/Poppy/data/training/processed/tokenbase.txt")