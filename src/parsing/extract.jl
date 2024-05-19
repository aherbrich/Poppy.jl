include("filter_elo.jl")
include("../Poppy.jl")
using .Poppy
using Plots

function square_to_index(square::String)
    file = square[1]
    rank = square[2]
    return (file - 'a') + 8 * (rank - '1')
end

# a move is given in Standard Algebraic Notation (SAN)
# for more: (https://en.wikipedia.org/wiki/Algebraic_notation_(chess))
function SAN_extract_move(board::Board, move_str::String)
    legals = generate_legals(board)

    #############################################
    # CASTLING
    if move_str == "O-O"
        moves = filter(move -> move.type == KING_CASTLE, legals)
        if length(moves) != 1 error("Invalid move: $move_str") end
        return moves[1]
    end

    if move_str == "O-O-O"
        moves = filter(move -> move.type == QUEEN_CASTLE, legals)
        if length(moves) != 1 error("Invalid move: $move_str") end
        return moves[1]
    end

    #############################################
    # PROMOTION
    if occursin("=" , move_str)
        # filter all promotion moves
        moves = filter(move -> (move.type & PROMOTION) != 0, legals)

        # filter by destination square
        dst_sq = square_to_index(move_str[end-3:end-2])
        moves = filter(move -> move.dst == dst_sq, moves)

        # filter by promotion piece
        promotion_piece = move_str[end] == 'N' ? KNIGHT_PROMOTION & 0x03 :
                          move_str[end] == 'B' ? BISHOP_PROMOTION & 0x03 :
                          move_str[end] == 'R' ? ROOK_PROMOTION & 0x03 :
                          move_str[end] == 'Q' ? QUEEN_PROMOTION & 0x03 : error("Invalid move: $move_str")
        moves = filter(move -> (move.type & 0x03) == promotion_piece, moves)

        if length(moves) == 1 return moves[1] end
        
        # filter by source file
        src_file = move_str[1] - 'a'
        moves = filter(move -> (move.src % 8) == src_file, moves)

        if length(moves) != 1 error("Invalid move: $move_str") end
        return moves[1]
    end
    
    #############################################
    # REGULAR MOVE

    # filter by destination square
    dst_sq = square_to_index(move_str[end-1:end])
    moves = filter(move -> move.dst == dst_sq, legals)

    if length(moves) == 1 return moves[1] end

    # filter by piece type
    piece_type = move_str[1] == 'N' ? KNIGHT :
                 move_str[1] == 'B' ? BISHOP :
                 move_str[1] == 'R' ? ROOK :
                 move_str[1] == 'Q' ? QUEEN :
                 move_str[1] == 'K' ? KING :
                 islowercase(move_str[1]) ? PAWN : error("Invalid move: $move_str")

    moves = filter(move -> (board.squares[move.src + 1] & 0x07) == piece_type, moves)

    if length(moves) == 1 return moves[1] end

    # if we are here, then there are two (or three) pieces of the same type
    # that can move to the same square -> they will differ in 
    # file or rank (or both)
    
    # filter by rank (ambiguous only by rank)
    if isuppercase(move_str[1]) && isnumeric(move_str[2])
        src_rank = move_str[2] - '1'
        moves = filter(move -> (move.src >> 3) == src_rank, moves)
        if length(moves) == 1 return moves[1] end
    end

    # filter by file (ambiguous only by file)
    src_file = islowercase(move_str[1]) ? move_str[1] - 'a' : move_str[2] - 'a'
    moves = filter(move -> (move.src % 8) == src_file, moves)

    if length(moves) == 1 return moves[1] end

    # filter by rank (ambiguous by both file and rank)
    src_rank = move_str[3] - '1'
    moves = filter(move -> (move.src >> 3) == src_rank, moves)

    if length(moves) != 1 error("Invalid move: $move_str") end

    return moves[1]
end

# Define a gradient function that takes a number between 0.0 and 1.0 and returns a color
function gradient(value::Float64)
    return RGB(1.0 - value, value, 0.0)
end

function simulate_games(filename::String)
    println("Simulating games from $filename")
    file = open(filename, "r")
    # vector of dicts with key = nr of legal moves, value = nr of occurences
    # every entry in the vector is a dict corresponding moves in phase 
    # 1-20, 21-40, 41-60, 61-80, 81-100 ...
    legal_move_distribution = Vector{Dict{Int, Any}}()

    while !eof(file)
        line = readline(file)
        line = strip(line)

        if isempty(line)
            continue
        end

        if startswith(line, "[") && endswith(line, "]")
            continue
        else startswith(line, "")
            board = Board()
            set_by_fen!(board, "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")
            moves = split(clean_moves_str(String(line)))
            for (i, move) in enumerate(moves)
                # log number of moves for statistics
                nr_of_moves = length(generate_legals(board))
                idx_of_dict = (i ÷ 20) + 1
                if length(legal_move_distribution) < idx_of_dict
                    push!(legal_move_distribution, Dict{Int, Any}())
                end

                if haskey(legal_move_distribution[idx_of_dict], nr_of_moves)
                    legal_move_distribution[idx_of_dict][nr_of_moves] += 1
                else
                    legal_move_distribution[idx_of_dict][nr_of_moves] = 1
                end
                
                # extract move from string and play it
                mv = SAN_extract_move(board, String(move))
                do_move!(board, mv)
            end
        end
    end

    #############################################
    # PLOTTING

    # for every dict scale all values to sum up to 1
    for i in 1:length(legal_move_distribution)
        sum_of_values = sum(values(legal_move_distribution[i]))
        for (key, value) in legal_move_distribution[i]
            legal_move_distribution[i][key] = value / sum_of_values
        end
    end

    # for every dict in the vector, plot the distribution of legal moves
    img = plot(legal_move_distribution[1],label="0-20", linewidth=3, cgrad=:thermal)
    for i in 2:length(legal_move_distribution)
        if i > 7
            break
        end
        plot!(legal_move_distribution[i], label = "$(20*(i-1)+1)-$(20*i)", linewidth=3, cgrad=:thermal)
    end
    display(img)
end

simulate_games("/Users/aherbrich/src/Poppy/src/parsing/elo2500.pgn")
