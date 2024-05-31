struct BoardFeatures
    hashes::Vector{UInt64}
end

function BoardFeatures(board::Board)
    hashes = Vector{UInt64}()

    _, legals = generate_legals(board)
    if length(legals) != 0
        for move in legals
            push!(hashes, move_to_hash(move))
        end
    end

    return BoardFeatures(hashes)
end

function Base.iterate(iter::BoardFeatures, state=(1, 2))
    i, j = state

    if length(iter.hashes) == 0
        if j == 2
            return UInt64(0), (i, j+1)
        else
            return nothing
        end
    else
        while i <= length(iter.hashes)
            if j <= length(iter.hashes)
                return (iter.hashes[i] ⊻ iter.hashes[j]), (i, j+1)
            else
                return iter.hashes[i], (i+1, i+2)
            end
        end
    end

    return nothing
end

function extract_features_from_all_boards(board::Board, legals::Vector{Move})
    features_of_all_boards = Vector{BoardFeatures}()

    for move in legals
        do_move!(board, move)
        push!(features_of_all_boards, BoardFeatures(board))
        undo_move!(board, move)
    end

    return features_of_all_boards
end