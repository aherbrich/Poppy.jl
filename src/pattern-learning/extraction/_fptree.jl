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

struct ItemStats
    freq::Int
    rank::Int
end

mutable struct FPTreeNode
    item::Int
    count::Int
    parent::Union{FPTreeNode, Nothing}
    children::Dict{Int, FPTreeNode}

    next::Union{FPTreeNode, Nothing}
end

function FPTreeNode(item::Int, count::Int, parent::Union{FPTreeNode, Nothing})
    return FPTreeNode(item, count, parent, Dict{Int, FPTreeNode}(), nothing)
end

function Base.show(io::IO, node::FPTreeNode)
    print(io, "FPTreeNode(item=$(node.item), count=$(node.count))")
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
    println(io, "FPTree:")
    println(io, "  - Header table with $(length(tree.header_table)) entries")
    # print first 2 and last 2 entries, with ellipsis in between
    for (i, (key, value)) in enumerate(tree.header_table)
        if i <= 2 || i > length(tree.header_table) - 2
            println(io, "    - Item $key: $value")
        elseif i == 3
            println(io, "    ...")
        end
    end
end

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

function insert!(tree::FPTree, pattern::Vector{Int}; count::Int=1)
    node = tree.root
    for item in pattern
        if haskey(node.children, item)
            # increment count of existing child node and continue traversal
            node = node.children[item]
            node.count += count
        else
            # add new child node
            child = FPTreeNode(item, count, node)
            node.children[item] = child

            # update header table
            if haskey(tree.header_table, item)
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

    return stats
end

function construct_fptree(pattern_base::PatternBase, min_support::Int)
    tree = FPTree(min_support)

    # FIRST PASS: count frequency of each item and determine ordering
    tree.item_stats = extract_item_freqs_and_ranks(pattern_base)

    # SECOND PASS: insert patterns into FP-tree
    for (pattern, count) in zip(pattern_base.patterns, pattern_base.counts)
        filter!(item -> tree.item_stats[item].freq >= tree.min_support, pattern)
        sort!(pattern, by=item -> tree.item_stats[item].rank)

        if !isempty(pattern)
            insert!(tree, pattern, count=count)
        end
    end 

    return tree
end

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


last_mfi = nothing

function check_subset(mfi_tree::FPTree, items::Vector{Int})
    # check if head + frequent items in conditional pattern base is a subset of last maximal frequent itemset
    if !isnothing(last_mfi) && issubset(items, last_mfi)
        return true
    end

    # else check if head + frequent items in conditional pattern base 
    # is a subset of any existing maximal frequent itemset

    # 1. sort items by rank of items in mfi_tree
    sort!(items, by=item -> mfi_tree.item_stats[item].rank, rev=true)

    # 2. retrieve the first item (least frequent item)
    if !haskey(mfi_tree.header_table, items[1])
        # 3.1 if the least frequent item is not in the header table it can not be a subset
        return false
    end

    node = mfi_tree.header_table[items[1]]

    # 3.2 if there is only one item in the list, and it is in the header table, it is a subset
    if length(items) == 1
        return true
    end

    # 3.3 traverse the linked list of the least frequent item
    while !isnothing(node)
        # 4. check if the path from the least frequent item to the root contains all items
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

    return false
end

function fpmax(tree::FPTree, mfi_tree::FPTree, head::Vector{Int})
    if isnothing(tree.root) || length(tree.root.children) == 0
        return
    elseif is_single_path(tree)
        # extract the path + (concatenate) the head
        path = Vector{Int}()
        node = tree.root
        while !isempty(node.children)
            node = first(values(node.children))
            push!(path, node.item)
        end
        path = vcat(path, head)
        sort!(path, by=item -> mfi_tree.item_stats[item].rank)

        # path support is the count of the last node in the path 
        # or more specifically, every node should have the same count (due to the fp-tree property)
        path_support = node.count
        
        insert!(mfi_tree, path, count=path_support)
        
        last_mfi = path
    else
        # for every header item in reverse order
        for (item, node) in sort(collect(tree.header_table), by=x -> tree.item_stats[x[1]].rank, rev=true)
            # add item to head
            append!(head, item)

            # construct conditional pattern base
            cpb = PatternBase()
            while !isnothing(node)
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
                node = node.next
            end

            # construct conditional FP-tree
            cpb_tree = construct_fptree(cpb, tree.min_support)
            
            # check if new head + frequent items in conditional pattern base 
            # is a subset of any existing maximal frequent itemset
            is_subset = check_subset(mfi_tree, vcat(head, collect(keys(cpb_tree.header_table))))

            # if not, recursively mine the conditional FP-tree
            if !is_subset
                fpmax(cpb_tree, mfi_tree, head)
            end

            # remove item from head
            pop!(head)
        end
    end
end

function fpmax(tree::FPTree)
    mfi_tree = FPTree(tree.min_support)
    mfi_tree.item_stats = tree.item_stats

    fpmax(tree, mfi_tree, Vector{Int}())

    return mfi_tree
end

######### EXAMPLE #########

patterns = [
    ['f', 'a', 'c', 'd', 'g', 'i', 'm', 'p'],
    ['a', 'b', 'c', 'f', 'l', 'm', 'o'],
    ['b', 'f', 'h', 'j', 'o'],
    ['b', 'c', 'k', 's', 'p'],
    ['a', 'f', 'c', 'e', 'l', 'p', 'm', 'n'],
    ['f', 'c', 'g', 's']
]

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

pattern_base = PatternBase(patterns)
tree = construct_fptree(pattern_base, 3)
mfi_tree = fpmax(tree)

println("Maximal frequent itemsets:")
print_tree(mfi_tree, as_char=true)

