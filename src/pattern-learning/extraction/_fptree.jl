#######################################################
# PatternBase
# = data structure to store patterns and (optionally) 
# their frequencies
#######################################################

struct PatternBase
    patterns::Vector{Vector{Int}}
    counts::Vector{Int}
end

function PatternBase()
    return PatternBase(Vector{Vector{Int}}(), Vector{Int}())
end

function PatternBase(patterns::Vector{Vector{T}}, counts::Vector{Int}) where T 
    return length(patterns) != length(counts) ? error("patterns and counts must have the same length") : PatternBase(patterns, counts)
end

function PatternBase(patterns::Vector{Vector{T}}) where T
    return PatternBase(convert(Vector{Vector{Int}}, patterns), fill(1, length(patterns)))
end

function PatternBase(filename::T; max_patterns::Int=typemax(Int)) where T<:AbstractString
    patterns = Vector{Vector{Int}}()

    count = 0
    open(filename) do file
        for line in eachline(file)
            count += 1
            line = strip(line)
            pattern = Vector{Int}()
            for item in split(line)
                push!(pattern, parse(Int, item))
            end
            push!(patterns, pattern)
            if count >= max_patterns break end
        end
    end

    return PatternBase(patterns)
end

#######################################################
# FPTreeNode
# = node in the FP-tree, for more information see:
# https://dl.acm.org/doi/pdf/10.1145/335191.335372
#######################################################

mutable struct FPTreeNode
    item::Int
    count::Int
    parent::Union{FPTreeNode, Nothing}
    children::Dict{Int, FPTreeNode}

    next::Union{FPTreeNode, Nothing}

    function FPTreeNode(item::Int, count::Int, parent::Union{FPTreeNode, Nothing}, children::Dict{Int, FPTreeNode}, next::Union{FPTreeNode, Nothing})
        return (count < 0) ? error("count must be non-negative") : new(item, count, parent, children, next)
    end
end

function FPTreeNode(item::Int, count::Int, parent::Union{FPTreeNode, Nothing})
    return FPTreeNode(item, count, parent, Dict{Int, FPTreeNode}(), nothing)
end

function Base.show(io::IO, node::FPTreeNode)
    print(io, "FPTreeNode(item=$(node.item), count=$(node.count))")
end

#######################################################
# FPTree
# = data structure to store the FP-tree; this includes
# the root node, a so-called header table (for fast
# access to nodes of the same item(id)), frequency and
# ordering information of items (needed for prefix
# path generation), and the minimum support threshold
#######################################################

struct ItemStats
    freq::Int
    rank::Int
end

mutable struct FPTree
    root::Union{FPTreeNode, Nothing}
    header_table::Dict{Int, FPTreeNode}
    item_stats::Dict{Int, ItemStats}
    min_support::Int

    function FPTree(root::Union{FPTreeNode, Nothing}, header_table::Dict{Int, FPTreeNode}, item_stats::Dict{Int, ItemStats}, min_support::Int)
        return (min_support < 0) ? error("min_support must be non-negative") : new(root, header_table, item_stats, min_support)
    end
end

function FPTree(min_support::Int)
    return FPTree(FPTreeNode(0, 0, nothing), Dict{Int, FPTreeNode}(), Dict{Int, ItemStats}(), min_support)
end

function Base.show(io::IO, tree::FPTree)
    # mostly only here to supress the recursive printing of the tree
    println(io, "FPTree(min_support=$(tree.min_support))")
end

#######################################################
# FPTree Pretty Printing
# = utility functions to print the FP-tree in a more
# human-readable format; useful for debugging
#######################################################

function print_tree(node::FPTreeNode, prefix::String, as_char::Bool)
    item = if as_char convert(Char, node.item) else node.item end
    println(prefix * "└── " * string(item) * " (" * string(node.count) * ")")
    
    for (key, child) in node.children
        new_prefix = prefix * "   "
        print_tree(child, new_prefix, as_char)
    end
end

function print_tree(tree::FPTree; as_char::Bool=false)
    if !isnothing(tree.root)
        println("FPTree(min_support=$(tree.min_support)):")
        for (key, child) in tree.root.children
            print_tree(child, "", as_char)
        end
    else
        println("Empty FPTree(min_support=$(tree.min_support))")
    end
end

#######################################################
# FP-Tree Construction
# = utility functions to construct the FP-tree from a
# pattern base
#######################################################


function insert!(tree::FPTree, pattern::Vector{Int}; count::Int=1)
    node = tree.root
    for item in pattern
        if haskey(node.children, item)
            # increment count of existing child node and continue traversal
            node = node.children[item]
            node.count += count
        else
            # add new child node, with some initial count
            child = FPTreeNode(item, count, node)
            node.children[item] = child

            # update header table
            if haskey(tree.header_table, item)
                # if item is already in the header table
                # append child to the end of the linked list
                current = tree.header_table[item]
                while !isnothing(current.next)
                    current = current.next
                end
                current.next = child
            else
                tree.header_table[item] = child
            end

            # continue traversal
            node = child
        end
    end
end

function extract_item_freqs_and_ranks(pattern_base::PatternBase)
    stats = Dict{Int, ItemStats}()

    # count frequency of each item
    for (pattern, count) in zip(pattern_base.patterns, pattern_base.counts)
        for item in pattern
            if haskey(stats, item)
                stats[item] = ItemStats(stats[item].freq + count, 0)
            else
                stats[item] = ItemStats(count, 0)
            end
        end
    end

    # determine ordering (rank of each item, later used for sorting)
    arr = sort(collect(stats), by=x -> x[2].freq, rev=true)
    for i in eachindex(arr)
        stats[arr[i][1]] = ItemStats(arr[i][2].freq, i)
    end

    # essentially, all items are ordered by frequency, and
    # items with the same frequency are ordered by some arbitrary
    # (sort-specific) order. important(!) is that the order is consistent
    # on all consecutive sorts of the items (by frequency). for this reason
    # all consecutive sorts will use the rank attribute (computed above) 
    # which introduces a total order for stable sorting
    
    return stats
end

function construct_fptree(pattern_base::PatternBase, min_support::Int)
    tree = FPTree(min_support)

    # FIRST PASS: count frequency of each item and determine ordering
    tree.item_stats = extract_item_freqs_and_ranks(pattern_base)

    # SECOND PASS: insert patterns into FP-tree
    for (pattern, count) in zip(pattern_base.patterns, pattern_base.counts)
        # filter out items that do not meet the minimum support threshold
        filter!(item -> tree.item_stats[item].freq >= tree.min_support, pattern)
        # sort items by their frequency (internally by rank, for stability)
        sort!(pattern, by=item -> tree.item_stats[item].rank)

        if !isempty(pattern)
            insert!(tree, pattern, count=count)
        end
    end 

    return tree
end


#######################################################
# FP-Max
# = utility functions to mine maximal frequent itemsets
# from the FP-tree
#######################################################

last_mfi = nothing

function is_single_path(tree::FPTree)
    node = tree.root
    while !isempty(node.children)
        if length(node.children) > 1
            return false
        end
        node = first(values(node.children))
    end

    return true
end

function check_subset(mfi_tree::FPTree, items::Vector{Int})
    # this function checks if items is a subset of any existing maximal frequent itemset

    # it has been found that in fp-tree mining, itemsets are more frequently
    # subsets of the most recently found maximal frequent itemset, 
    # hence we check this first; for more information see: 
    # https://users.encs.concordia.ca/~grahne/papers/hpdm03.pdf

    # 1. check if items is a subset of the most recently found mfi
    if !isnothing(last_mfi) && issubset(items, last_mfi)
        return true
    end

    # 2. else check if items is a subset of any maximal frequent itemset in the mfi_tree

    # fortunately, we do not need to check all maximal frequent itemsets.
    # rather, we can sort the items by the ordering used for insertion into 
    # the mfi_tree, and then traverse the linked list of the least frequent item in items.
    #
    # for every node in the linked list, we traverse the path to the root and check
    # if the path contains all items in items; this is possible in O(n) time due to 
    # the same ordering of items as in the mfi_tree. we only have to check this
    # for the least frequent item in items, as the path to the root contains all
    # items in items only if the least frequent item is (also) in the path to the root


    # 2.1 sort items by rank of insertion into the mfi_tree
    sort!(items, by=item -> mfi_tree.item_stats[item].rank, rev=true)

    # 2.2. check if the least frequent item is in the header table
    if !haskey(mfi_tree.header_table, items[1])
        # if the least frequent item is not in the header table 
        # it can not be a subset (since there exist no mfi with this item)
        return false
    end

    # 2.3 retrieve the least frequent item from the header table
    node = mfi_tree.header_table[items[1]]
    if length(items) == 1
        # if the least frequent item is the only item in items
        # it is a subset of an existing maximal frequent itemset
        # (since the least frequent item is in the header table,
        # and is the only item in items)
        return true
    end

    # 2.4 traverse the linked list of the least frequent item
    while !isnothing(node)
        # 2.5 for every such node, check if the path from the node to the root contains all items
        # and if so, items is a subset of an existing maximal frequent itemset
        
        # linear time check if path contains all items
        # (makes use of ordering)
        idx = 2
        tmp = node.parent
        while !isnothing(tmp) && tmp.item != 0
            if tmp.item == items[idx]
                idx += 1
                if idx > length(items) return true end
            end

            tmp = tmp.parent
        end

        node = node.next
    end

    # if no maximal frequent itemset was found, of which items is a subset
    # we can return false

    return false
end

function fpmax(tree::FPTree, mfi_tree::FPTree, head::Vector{Int}, head_support::Int=0)
    if is_single_path(tree) || length(tree.root.children) == 0
        # extract the path (possibly empty) 
        path = Vector{Int}()
        node = tree.root
        while !isempty(node.children)
            node = first(values(node.children))
            push!(path, node.item)
        end
        # + (concatenate with) the head
        path = vcat(path, head)

        # insert mfi into mfi_tree with the same ordering as the original tree
        sort!(path, by=item -> mfi_tree.item_stats[item].rank)
        insert!(mfi_tree, path, count=0) # count is irrelevant for us
        
        # update most recently found maximal frequent itemset
        last_mfi = path
    else
        # for every header item in reverse order
        for (item, node) in sort(collect(tree.header_table), by=x -> tree.item_stats[x[1]].rank, rev=true)
            # add item to head
            append!(head, item)

            # construct conditional pattern base (conditioned on item 
            # or rather, considering recursive fpmax call => conditional on head)
            cpb = PatternBase()

            # traverse the linked list of the item
            while !isnothing(node)
                # construct path (conditional pattern) by 
                # traversing the from the node to the root
                path = Vector{Int}()
                count = node.count
                tmp = node.parent
                while !isnothing(tmp) && tmp.item != 0
                    push!(path, tmp.item)
                    tmp = tmp.parent
                end

                if !isempty(path)
                    push!(cpb.patterns, path)
                    push!(cpb.counts, count)
                end

                # continue with next node in linked list
                node = node.next
            end

            # construct conditional FP-tree from conditional pattern base
            cpb_tree = construct_fptree(cpb, tree.min_support)
            
            # check if new head + new frequent items in conditional pattern base 
            # is a subset of any existing maximal frequent itemset  
            is_subset = check_subset(mfi_tree, vcat(head, collect(keys(cpb_tree.header_table))))

            # if not (a subset), recursively mine the conditional FP-tree
            if !is_subset
                fpmax(cpb_tree, mfi_tree, head)
            end

            # remove item from head, before next iteration
            pop!(head)
        end
    end
end

function fpmax(tree::FPTree)
    # construct an empty tree to store the maximal frequent itemsets
    
    # min_support is irrelevant for us; if pattern is added to the mfi_tree
    # it has met the minimum support threshold
    mfi_tree = FPTree(0) 

    # we need the same ordering for insertion into the mfi_tree
    # as for the original tree, to ensure correctness of fpmax
    mfi_tree.item_stats = tree.item_stats 

    fpmax(tree, mfi_tree, Vector{Int}())

    return mfi_tree
end

######### EXAMPLE #########

# patterns = [
#     ['f', 'a', 'c', 'd', 'g', 'i', 'm', 'p'],
#     ['a', 'b', 'c', 'f', 'l', 'm', 'o'],
#     ['b', 'f', 'h', 'j', 'o'],
#     ['b', 'c', 'k', 's', 'p'],
#     ['a', 'f', 'c', 'e', 'l', 'p', 'm', 'n'],
#     ['f', 'c', 'g', 's']
# ]

# patterns = [
#     ['a', 'b', 'c', 'e', 'f', 'o'],
#     ['a', 'c', 'g'],
#     ['e', 'i'],
#     ['a', 'c', 'd', 'e', 'g'],
#     ['a', 'c', 'e', 'g', 'l'],
#     ['e', 'j'],
#     ['a', 'b', 'c', 'e', 'f', 'p'],
#     ['a','c','d'],
#     ['a', 'c', 'e', 'g', 'm'],
#     ['a', 'c', 'e', 'g', 'n'],
# ]

# pattern_base = PatternBase(patterns)
# tree = construct_fptree(pattern_base, 3)
# mfi_tree = fpmax(tree)

# println("Maximal frequent itemsets:")
# print_tree(mfi_tree, as_char=true)
