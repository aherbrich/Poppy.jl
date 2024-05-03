struct Color{n}
end

Color(n::UInt8) = Color{n}()

mutable struct IrreversibleInfo
    ep_square::UInt8
    castling_rights::UInt8
    fifty_move_counter::UInt16
    captured_piece::UInt8

    # strictly speaking, the hash is reversible
    # but we don't want to recalculate it on every 
    # unmake so we store it here
    hash::UInt64                
end

mutable struct Board
    # bitboards (piece-centric)
    bb_for::Vector{UInt64}              # occupied squares for each piece type
    bb_white::UInt64                    # squares occupied by white
    bb_black::UInt64                    # squares occupied by black
    bb_occ::UInt64                      # all occupied squares

    # (redundant) array representation (square-centric)
    squares::Vector{UInt8}                # piece type on each square

    # (easily) reversible information
    side_to_move::Color
    ply::UInt16                         # halfmove clock (starts at 1)
    
    # irreversible information
    history::Vector{IrreversibleInfo}   # history of irreversible information
                                        # ep_square, castling_rights, fifty_move_counter
                                        # + hash (which strictly speaking is reversible)
end

function Board()
    return Board(
        fill(0x0000000000000000, 14),
        0x0000000000000000,
        0x0000000000000000,
        0x0000000000000000,
        fill(0x00, 64),
        Color(0x00),
        0,
        [IrreversibleInfo(0, 0, 0, 0, 0) for _ in 1:1024]
    )
end

function clear!(board::Board)
    board.bb_for .= 0x0000000000000000
    board.bb_white = 0x0000000000000000
    board.bb_black = 0x0000000000000000
    board.bb_occ = 0x0000000000000000
    board.squares .= 0x00
    board.side_to_move = Color(0x00)
    board.ply = 0
    board.history = [IrreversibleInfo(0, 0, 0, 0, 0) for _ in 1:1024]
end

function set_piece!(board::Board, piece::UInt8, square::Int)
    board.bb_for[piece] |= 1 << square
    board.bb_occ |= 1 << square

    if is_white(piece) board.bb_white |= 1 << square else board.bb_black |= 1 << square end
    
    board.squares[square+1] = piece
end

function set_by_fen!(board::Board, fen::String)
    fen = strip(fen)

    split_fen = split(fen, " ")
    if length(split_fen) != 6
        throw(ArgumentError("Invalid FEN string - not all fields present"))
    end
    
    # CLEAR BOARD
    clear!(board)

    # SET PIECES
    position = split_fen[1]

    file = 0
    rank = 7

    for c in position
        sq = rank * 8 + file
        if c == 'P' set_piece!(board, WHITE_PAWN, sq)
        elseif c == 'N' set_piece!(board, WHITE_KNIGHT, sq)
        elseif c == 'B' set_piece!(board, WHITE_BISHOP, sq)
        elseif c == 'R' set_piece!(board, WHITE_ROOK, sq)
        elseif c == 'Q' set_piece!(board, WHITE_QUEEN, sq)
        elseif c == 'K' set_piece!(board, WHITE_KING, sq)
        elseif c == 'p' set_piece!(board, BLACK_PAWN, sq)
        elseif c == 'n' set_piece!(board, BLACK_KNIGHT, sq)
        elseif c == 'b' set_piece!(board, BLACK_BISHOP, sq)
        elseif c == 'r' set_piece!(board, BLACK_ROOK, sq)
        elseif c == 'q' set_piece!(board, BLACK_QUEEN, sq)
        elseif c == 'k' set_piece!(board, BLACK_KING, sq)
        elseif isdigit(c) file += parse(Int, c) - 1
        elseif c == '/' rank -= 1; file = -1
        else throw(ArgumentError("Invalid FEN string - error in actual board position"))
        end
        file += 1
    end

    # SET SIDE TO MOVE
    side = split_fen[2]
    if side == "w" board.side_to_move = Color(WHITE)
    elseif side == "b" board.side_to_move = Color(BLACK)
    else throw(ArgumentError("Invalid FEN string - error in side to move"))
    end

    flags::IrreversibleInfo = IrreversibleInfo(0, 0, 0, 0, 0)

    # SET CASTLING RIGHTS
    castling = split_fen[3]

    flags.castling_rights = NO_CASTLING
    if castling != "-"
        for c in castling
            if c == 'K' flags.castling_rights |= CASTLING_WK
            elseif c == 'Q' flags.castling_rights |= CASTLING_WQ
            elseif c == 'k' flags.castling_rights |= CASTLING_BK
            elseif c == 'q' flags.castling_rights |= CASTLING_BQ
            else throw(ArgumentError("Invalid FEN string - error in castling rights"))
            end
        end
    end

    # SET EN PASSANT SQUARE
    ep_square = split_fen[4]

    if ep_square == "-"
        flags.ep_square = NO_SQUARE
    else
        if ep_square[1] < 'a' || ep_square[1] > 'h' || ep_square[2] < '1' || ep_square[2] > '8'
            throw(ArgumentError("Invalid FEN string - error in en passant square"))
        end

        file = ep_square[1] - 'a'
        rank = ep_square[2] - '1'
        flags.ep_square = rank * 8 + file
    end

    # SET HALFMOVE COUNTER
    halfmove = split_fen[5]
    try
        flags.fifty_move_counter = parse(UInt16, halfmove)
    catch
        throw(ArgumentError("Invalid FEN string - error in halfmove counter"))
    end

    # SET FULLMOVE (PLY) NUMBER
    try
        board.ply = parse(UInt16, split_fen[6])
    catch
        throw(ArgumentError("Invalid FEN string - error in fullmove number"))
    end

    # PUSH IRREVERSIBLE INFO
    for i in 1:board.ply
        board.history[i].ep_square = flags.ep_square
        board.history[i].castling_rights = flags.castling_rights
        board.history[i].fifty_move_counter = flags.fifty_move_counter
        board.history[i].hash = 0
    end
end

function Base.show(io::IO, board::Board)
    for rank in 7:-1:0
        for file in 0:7
            sq = rank * 8 + file
            piece = board.squares[sq+1]
            if piece == NO_PIECE
                print(io, "- ")
            else
                print(io, CHARACTERS[piece], " ")
            end
        end

        if rank != 0
            println(io)
        end
    end

    println(io)
    println(io, "Side to move: ", board.side_to_move == Color(WHITE) ? "White" : "Black")
    println(io, "Castling rights: ", string(board.history[board.ply].castling_rights, base=2, pad=4))
    # convert ep_square to algebraic notation
    if board.history[board.ply].ep_square != NO_SQUARE
        println(io, "En passant square: ", string('a' + file(board.history[board.ply].ep_square)), string('1' + rank(board.history[board.ply].ep_square), " (sq:", string(board.history[board.ply].ep_square), ")"))
    else
        println(io, "En passant square: -")
    end

    # println(io, "")
    # println(io, "White Pawns:        White Knights:      White Bishops:      White Rooks:        White Queens:       White King:       White Pieces:\n")
    # mask::UInt64 = 0xff00000000000000
    # shift = 56
    # for _ in 1:8
    #     println(io, join(c * " " for c in reverse(string(((board.bb_for[WHITE_PAWN] & mask) >> shift), base=2, pad=8))), "    ", join(c * " " for c in reverse(string(((board.bb_for[WHITE_KNIGHT] & mask) >> shift), base=2, pad=8))), "    ", join(c * " " for c in reverse(string(((board.bb_for[WHITE_BISHOP] & mask) >> shift), base=2, pad=8))), "    ", join(c * " " for c in reverse(string(((board.bb_for[WHITE_ROOK] & mask) >> shift), base=2, pad=8))), "    ", join(c * " " for c in reverse(string(((board.bb_for[WHITE_QUEEN] & mask) >> shift), base=2, pad=8))), "    ", join(c * " " for c in reverse(string(((board.bb_for[WHITE_KING] & mask) >> shift), base=2, pad=8))), "    ", join(c * " " for c in reverse(string(((board.bb_white & mask) >> shift), base=2, pad=8))))
    #     mask >>= 8
    #     shift -= 8
    # end

    # println(io, "")
    # println(io, "Black Pawns:        Black Knights:      Black Bishops:      Black Rooks:        Black Queens:       Black King:       Black Pieces:\n")
    # mask = 0xff00000000000000
    # shift = 56
    # for _ in 1:8
    #     println(io, join(c * " " for c in reverse(string(((board.bb_for[BLACK_PAWN] & mask) >> shift), base=2, pad=8))), "    ", join(c * " " for c in reverse(string(((board.bb_for[BLACK_KNIGHT] & mask) >> shift), base=2, pad=8))), "    ", join(c * " " for c in reverse(string(((board.bb_for[BLACK_BISHOP] & mask) >> shift), base=2, pad=8))), "    ", join(c * " " for c in reverse(string(((board.bb_for[BLACK_ROOK] & mask) >> shift), base=2, pad=8))), "    ", join(c * " " for c in reverse(string(((board.bb_for[BLACK_QUEEN] & mask) >> shift), base=2, pad=8))), "    ", join(c * " " for c in reverse(string(((board.bb_for[BLACK_KING] & mask) >> shift), base=2, pad=8))), "    ", join(c * " " for c in reverse(string(((board.bb_black & mask) >> shift), base=2, pad=8))))
    #     mask >>= 8
    #     shift -= 8
    # end

end
