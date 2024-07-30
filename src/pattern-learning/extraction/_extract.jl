using QuickHeaps

#######################################################
# MatchingTree & MatchingTreeNode
# data structure to hold "most frequent" patterns
# for efficient pattern matching
#######################################################

mutable struct MatchingTreeNode
    key::Int
    is_pattern::Bool
    parent::Union{MatchingTreeNode, Nothing}
    children::Dict{Int, MatchingTreeNode}

    function MatchingTreeNode(item::Int, is_pattern::Bool, parent::Union{MatchingTreeNode, Nothing})
        new(item, is_pattern, parent, Dict{Int, MatchingTreeNode}())
    end
end

function Base.show(io::IO, node::MatchingTreeNode)
    print(io, "MatchingTreeNode")
end

mutable struct MatchingTree
    root::MatchingTreeNode
    item_stats::Dict{Int, ItemStats}

    function MatchingTree(item_stats::Dict{Int, ItemStats})
        new(MatchingTreeNode(-1, false, nothing), item_stats)
    end
end

#######################################################
# MatchingTree Construction
# utility function to construct a matching tree
# from a vector of "frequent" patterns
#######################################################

function construct_matching_tree(patterns::Vector{Vector{Int}}, item_stats::Dict{Int, ItemStats})
    tree = MatchingTree(item_stats)

    for pattern in patterns
        # sort items in pattern by item rank (from initial fp-tree construction)
        sort!(pattern, by=item -> tree.item_stats[item].rank)

        # add pattern to matching tree, by travesing downwards
        # and adding nodes as necessary
        current = tree.root
        for item in pattern
            if !haskey(current.children, item)
                current.children[item] = MatchingTreeNode(item, false, current)
            end
            
            # if the current item is the last item in the pattern,
            # mark this node as a pattern node, i.e. if we reach this
            # node while traversing, we know that the path from the root
            # to this node is a pattern
            if item == pattern[end]
                current.children[item].is_pattern = true
            end

            current = current.children[item]
        end
    end

    return tree
end

#######################################################
# Most Frequent Patterns Extraction
#
# utility function to extract "most frequent" patterns;
# unlike fpgrwoth/fpmax this does not return the actual
# frequent itemsets, but some approximation of them.
# specifically, this function essentially extracts a 
# subtree of the fp-tree, namely the subtree with 
# max_patterns many nodes of highest frequency. 
#
# obviously, this suffers from the fact that very small
# patterns, or in general items which rarely occur alone
# but often in larger patterns, will not be extracted.
# however, this is a tradeoff for efficiency.
#######################################################

function extract_most_frequent_patterns(tree::FPTree, max_patterns::Int, min_freq::Int)
    # prioq with reverse ordering
    prioq = PriorityQueue{FPTreeNode, Int}(Base.ReverseOrdering())

    # push all children of the root node into the priority queue, using their frequency as priority
    for (_, child) in tree.root.children
        push!(prioq, (child, child.count))
    end

    # extract patterns
    patterns = Vector{Vector{Int}}()
    while !isempty(prioq) && length(patterns) < max_patterns
        # out of the pool of candidate nodes,
        # pop the one with the highest frequency
        node, freq = pop!(prioq)

        # we can abort pattern extraction if the frequency of the current node
        # is below the minimum frequency
        if freq < min_freq
            break
        end

        # push all children of the current node into the priority queue
        # since they are candidates for the next pattern
        for (_, child) in node.children
            push!(prioq, (child, child.count))
        end

        # extract the pattern by traversing the tree upwards
        # from the current node to the root node
        pattern = Vector{Int}()
        current = node
        while !isnothing(current.parent)
            push!(pattern, current.item)
            current = current.parent
        end

        push!(patterns, pattern)
    end

    return patterns
end


#######################################################
# Extract Subpatterns
# utility functions to extract subpatterns from a board;
# a board is a pattern itself, i.e. a set of items;
# the following functions extract all subpatterns of a
# given pattern from a matching tree (which itself holds
# the "most frequent" (sub)patterns)
#######################################################

function extract_subpatterns_from_board(board::Board, root::MatchingTree)
    board_pattern = Vector{Int}()
    for i in 1:64
        piece = board.squares[i]
        if piece == 0 continue end
        key = Int(64 * piece + (i - 1))
        if haskey(root.item_stats, key)
            push!(board_pattern, key)
        end
    end

    subpatterns = extract_subpatterns_from_pattern(root, board_pattern)

    return subpatterns
end

function extract_subpattern_from_board(fen::AbstractString, root::MatchingTree)
    board = Board()
    set_by_fen!(board, fen)
    return extract_subpatterns_from_board(board, root)
end

function __extract_subpatterns_from_pattern(node::MatchingTreeNode, pattern::Vector{Int})
    subpatterns = Vector{Vector{Int}}()
    for item in pattern
        if haskey(node.children, item)
            bigger_subpatterns = __extract_subpatterns_from_pattern(node.children[item], pattern[2:end])

            if node.children[item].is_pattern
                if isempty(bigger_subpatterns)
                    push!(subpatterns, [item])
                end
                for pattern in bigger_subpatterns
                    push!(subpatterns, vcat([item], pattern))
                end
            else
                for pattern in bigger_subpatterns
                    push!(subpatterns, pattern)
                end
            end
        end
    end

    return subpatterns
end

function extract_subpatterns_from_pattern(tree::MatchingTree, pattern::Vector{Int})
    sort!(pattern, by=item -> tree.item_stats[item].rank)
    return __extract_subpatterns_from_pattern(tree.root, pattern)
end