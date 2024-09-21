struct BoardFeatures
    hashes::Vector{UInt64}
end

function BoardFeatures(board::Board, feature_set::Symbol)
    #############################################
    # FEATURE SET - possible moves
    if feature_set == :possible_moves
        hashes = Vector{UInt64}()

        _, legals = generate_legals(board)
        if length(legals) != 0
            for move in legals
                move_id = ((UInt(move.src) << 10) | (UInt(move.dst) << 4) | UInt(move.type))
                push!(hashes, move_id)
            end
        end

        if length(hashes) == 0
            push!(hashes, UInt64(0))
        end

        return BoardFeatures(hashes)
    
    #############################################
    # FEATURE SET - pieces
    elseif feature_set == :pieces
        hashes = Vector{UInt64}()

        for square in 1:64
            piece = board.squares[square]
            if piece != NO_PIECE
                piece_id = ((UInt(piece) << 6) | UInt(square))
                push!(hashes, piece_id)
            end
        end

        return BoardFeatures(hashes)

    #############################################
    # FEATURE SET - combination of possible 
    #               moves and pieces
    elseif feature_set == :combi
        hashes = Vector{UInt64}()

        _, legals = generate_legals(board)
        if length(legals) != 0
            for move in legals
                move_id = ((UInt(move.src) << 10) | (UInt(move.dst) << 4) | UInt(move.type))
                push!(hashes, move_id)
            end
        end

        if length(hashes) == 0
            push!(hashes, UInt64(0))
        end

        for square in 1:64
            piece = board.squares[square]
            if piece != NO_PIECE
                piece_id = ((UInt(piece) << 6) | UInt(square)) << 16
                push!(hashes, piece_id)
            end
        end

        return BoardFeatures(hashes)
    else
        error("Invalid feature set")
    end
end

function Base.iterate(iter::BoardFeatures, state=1)
    if state > length(iter.hashes)
        return nothing
    end

    return (iter.hashes[state], state + 1)
end

function Base.keys(iter::BoardFeatures)
    return 1:length(iter.hashes)
end

function Base.length(iter::BoardFeatures)
    return length(iter.hashes)
end

function extract_features_from_all_boards(board::Board, legals::Vector{Move}, feature_set::Symbol)
    features_of_all_boards = Vector{BoardFeatures}()

    for move in legals
        do_move!(board, move)
        push!(features_of_all_boards, BoardFeatures(board, feature_set))
        undo_move!(board, move)
    end

    return features_of_all_boards
end