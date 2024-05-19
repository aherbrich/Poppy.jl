include("filter_elo.jl")
include("../Poppy.jl")
include("../factor-graph/graph.jl")

using .Poppy
using Plots

function move_to_hash(move, board)
    piece = board.squares[move.src + 1]
    return (Int64(piece) << 16) | (Int64(move.type) << 12) | (Int64(move.src) << 6) | Int64(move.dst) 
    # return (Int64(move.type) << 12) | (Int64(move.src) << 6) | Int64(move.dst) 
end

function idx_to_square(idx)
    file = 'a' + (idx % 8)
    rank = '1' + (idx >> 3)
    return string(file, rank)
end
function hash_to_move(hash)
    piece = ((hash >> 16) & 0x07) == PAWN ? "" :
            ((hash >> 16) & 0x07) == KNIGHT ? "N" :
            ((hash >> 16) & 0x07) == BISHOP ? "B" :
            ((hash >> 16) & 0x07) == ROOK ? "R" :
            ((hash >> 16) & 0x07) == QUEEN ? "Q" :
            ((hash >> 16) & 0x07) == KING ? "K" : error("Invalid piece")

    src = idx_to_square((hash >> 6) & 0x3F)
    dst = idx_to_square(hash & 0x3F)

    return string(piece, src, dst)
end

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

function simulate_games(filename::String)
    println("Simulating games from $filename")
    file = open(filename, "r")
    graph = Graph()
    count = 0

    while !eof(file)
        line = readline(file)
        line = strip(line)

        if isempty(line)
            continue
        end

        if startswith(line, "[") && endswith(line, "]")
            continue
        else startswith(line, "")
            count += 1
            board = Board()
            set_by_fen!(board, "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")
            moves = split(clean_moves_str(String(line)))
            for (i, move) in enumerate(moves)
                moves = generate_legals(board)
                hashes = [move_to_hash(mv, board) for mv in moves]

                add_ranking_problem!(graph, hashes)

                # extract move from string and play it
                mv = SAN_extract_move(board, String(move))
                do_move!(board, mv)
            end

            if count >= 51
                break
            end

        end
    end

    println("Ranking moves")
    res = rank(graph)
    
    # sort dict res by value
    res = sort(collect(res), by=x->x[2].τ/x[2].ρ, rev=false)

    for (i, (move, urgency)) in enumerate(res)
        println("   $i: $(hash_to_move(move)) - $urgency")
    end
end

simulate_games("/Users/aherbrich/src/Poppy/src/parsing/elo2500.pgn")
