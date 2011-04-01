# On this file, trees are implemented.
exports ?= window ?= this
  
# # Trees
# Trees are collections of elements organized on a hierarchy. The tree structure starts with
# zero or more root elements. Each element can then have zero or more child elements. Element order
# on each level of the hierarchy is preserved.
exports.Tree = class Tree
  # ## Creating a Tree
  # The `constructor` takes an array of root `elements` for the new tree as a parameter.
  constructor: (elements = []) ->
    throw new Error 'element does not provide .getUUID() method' for element in elements when not element.getUUID?
    @__elements = [elements...]
    @__roots = [elements...]
    @__parent = {}
    @__children = {}
    @__children[element.getUUID()] = [] for element in elements
  
  # ## Adding a Single Element to the Tree
  # The `add` function is a simple wrapper to `merge`.
  add: (element, reference = {}, atomic) ->
    @merge new Tree([element]), reference, atomic
    
  # ## Checking for Element Presence
  # The `contains` function returns whether `element` is present in the tree.
  contains: (element) ->
    element.getUUID() of @__children
    
  # ## Getting all the tree elements
  # The `elements` function returns a list with all the elements of a tree
  elements: ->
    [@__elements...]
    
  # ## Getting the tree roots
  # The `roots` function returns a list with all the root elements of a tree
  roots: ->
    [@__roots...]
  
  # ## *(non-public API)* Backing Up Tree Structure
  # This function is used internally along with `__restore` to ensure tree operations are atomic.
  # It shouldn't be called externally, as it might be removed on a future release.
  __backup: ->
    elements = [@__elements...]
    roots = [@__roots...]
    parent = {};
    parent[key] = [value...] for key, value of @__parent;
    children = {};
    children[key] = [value...] for key, value of @__children;
    { elements, roots, parent, children }

  # ## *(non-public API)* Restoring Backed up Tree Structure
  # This function is used internally along with `__backup` to ensure tree operations are atomic.
  # It shouldn't be called externally, as it might be removed on a future release.
  __restore: (backup) ->
    @__elements = backup.elements
    @__roots = backup.roots
    @__parent = backup.parent
    @__children = backup.children
  
  # ## Merging Trees
  # The `merge` function merges the contents of another `tree` into this one
  # it takes an optional reference parameter, an object with either a `before:`,
  # `after:` or `under:` property, to be used as a reference element for merging.       
  #
  # For example:
  #
  # `initial state:`
  #
  #       tree1                   tree2
  #
  #         |                       |
  #         A                       E  
  #       /   \                   /   \
  #      B     C                F      G
  #                                  /   \
  #                                 H     I
  #     
  # `tree1.merge tree2`
  #         
  #         tree1
  #
  #         ___|___
  #        A       E
  #      /  \     /   \
  #     B    C   F     G
  #                  /   \
  #                 H     I       
  #
  # `tree1.merge tree2, under: B`
  #      
  #             tree1
  #
  #               |
  #               A 
  #             /   \
  #           B       C
  #           |
  #           E
  #          / \
  #         F   G
  #            / \
  #           H   I
  #
  # Merging is performed with side effects, that is, the current tree is *modified* by the operation.
  # 
  # By default, merging is atomic, that is, if the operation fails somehow, the
  # tree is returned to a consistent state. As ensuring that can affect performance,
  # this behavior can be controlled by the `atomic` parameter.
  merge: (tree, {before, after, under} = {}, atomic = yes) ->
    # ### Detailed Explanation
    # To perform the merge, we start with some some checks:
    # 
    # - No element on the other `tree` must be already present on this tree.
    # - If a reference element is passed, it must be present on this tree.
    throw new Error 'element already present' for element in tree.elements() when this.contains element
    throw new Error 'reference not present' if before? and not (this.contains before) or
      after? and not (this.contains after) or
      under? and not (this.contains under)
    # After the checks, we make backup copies of the current tree 
    # structure to roll back to if something goes wrong during the merge.
    # Only performed if atomic is set to `yes`
    backup = @__backup() if atomic
      
    # *Start the transaction.*
    try
      # We add the other `tree` elements to our `@__elements` list,
      # and we register the elements children in our `@__children` table.
      for element in tree.elements()
        uuid = element.getUUID()
        @__elements.push element 
        @__children[uuid] = [tree.children(element)...]
      # Check for reference elements
      switch
        # `before` reference present. Insert root elements of the other `tree` before the `before` element on the tree.
        when before?
          parent = @__parent[before.getUUID()]
          @__parent[element.getUUID()] = parent;
          if parent then @__children[parent.getUUID()].splice(@__children[parent.getUUID()].indexOf(before), 0, tree.roots()...)
          else @__roots.splice(@__roots.indexOf(after) + 1, 0, tree.roots()...)
        # `after` reference present. Insert root elements of the other `tree` after the `after` element on the tree.
        when after?
          parent = @__parent[after.getUUID()]
          @__parent[element.getUUID()] = parent;
          if parent then @__children[parent.getUUID()].splice(@__children[parent.getUUID()].indexOf(after) + 1, 0, tree.roots()...)
          else @__roots.splice(@__roots.indexOf(after) + 1, 0, tree.roots()...)
        # `under` reference present. Insert root elements of the other `tree` under `under`.
        when under?
          @__parent[element.getUUID()] = under for element in tree.elements()
          @__children[under.getUUID()].push root for root in tree.roots()
        # No reference is present. Insert root elements of the other `tree` as roots of this tree.
        else
          @__roots.push root for root in tree.roots()
    # *The transaction failed.*
    # Revert to backups. Only performed if atomic is set to `yes`
    catch e
      @__restore backup if atomic
      # Propagate the error to the function above
      throw e
    # *End the transaction.*
    return
  
  # ## Getting an element's children
  # The `children` function returns the children of an element
  children: (element) ->
    if element?
      throw new Error "element not present" if not this .contains element
      [@__children[element.getUUID()]...]
    else
      [@__roots...]
    
  # ## Getting an element's parent
  # The `parent` function returns the parent of an element
  parent: (element) ->
    throw new Error "element not present" if not this .contains element
    @__parent[element.getUUID()]
            
  # ## Pruning the Tree
  # The `prune` method is used to remove elements from the tree. Upon completion,
  # it returns the removed elements.
  #
  # Example:
  #
  # `Initial tree`
  #
  #                   |
  #                   A 
  #                  / \
  #                 B   C
  #                /|  /|\
  #               J K D E F
  #               |      / \
  #               L     G   H
  #                         |
  #                         I
  #
  # `tree.prune F`
  #                 
  #                 tree                 return value
  #                   |                       |
  #                   A                       F
  #                  / \                     / \
  #                 B   C                   G   H
  #                /|  /|                       |
  #               J K D E                       I
  #               |         
  #               L          
  # Pruning is performed with side effects, that is, it affects the current tree.
  #
  # By default, pruning is atomic, that is, if the operation fails somehow, the
  # tree is returned to a consistent state. As ensuring that can affect performance,
  # this behavior can be controlled by the `atomic` parameter.
  prune: (element, atomic = yes) ->
    # The element used for pruning must be present on the tree.
    throw new Error "element not present" if not @contains element
    
    # A backup copy is created if we're on atomic mode.
    backup = @__backup() if atomic
    # *Start the Transaction*.
    try 
      # A new tree is created to store the pruned subtree. It starts with the element we used as a reference for pruning.
      subTree = new Tree([element])
      parent = @__parent[element.getUUID()]
      # We remove the element used for pruning
      if parent?
        (@__children[parent.getUUID()].splice (@__children[parent.getUUID()].indexOf element), 1)
      else
        (@__roots.splice (@__roots.indexOf element), 1)
      # Then we use recursion to both remove elements and copy them to the new tree.
      recurse = (element) => 
        for child in @children element
          subTree.add child, under: element
          recurse(child)
        delete @__children[element.getUUID()]
        delete @__parent[element.getUUID()]
        (@__elements.splice (@__elements.indexOf element), 1) # Lisp? :3
      recurse (element)
    # *The transaction failed*.
    # If we're on atomic mode, we restore the previous tree state.
    catch e
      @__restore backup if atomic
      # Propagate the error to the function above
      throw e
    # *End the Transaction*.
    # Return the removed subtree.
    subTree
    
  # ## JSON Serialization
  toJSON: ->
    toJSON = (element) => { element: (if element.toJSON? then element.toJSON() else element), children: (toJSON child for child in @children(element)) }
    { roots: (toJSON root for root in @__roots) }
    
exports.__test = () ->    
  class Element
    @uuid = 0
    getUUID: ->
      @__uuid
    constructor: ->
      @__uuid = Element.uuid++;
    
  e1 = new Element
  e2 = new Element
  e3 = new Element
  e4 = new Element
  e5 = new Element
  
  t1 = new Tree([e1, e2, e3])
  roots = t1.roots()
  throw new Error 1 if roots.length != 3
  throw new Error 2 if e1 not in roots or e2 not in roots or e3 not in roots
  
  t2 = new Tree [e1, e2]
  t2.add e3, under: e2
  t2.add e4, after: e2
  roots = t2.roots()
  throw new Error 3 if roots.length != 3
  throw new Error 4 if e4 not in roots or e1 not in roots or e2 not in roots or e3 in roots
  throw new Error 5 if e3 not in t2.children(e2)
  
  t2.add e5, under:e3
  throw new Error 6 if e5 not in t2.children(e3)
  
  t3 = t2.prune e2
  roots = t2.roots()
  throw new Error 7 if roots.length != 2
  throw new Error 8 if e1 not in roots or e4 not in roots or e2 in roots
  
  roots = t3.roots()
  throw new Error 9 if roots.length != 1
  throw new Error 10 if e2 not in roots
  throw new Error 11 if not e3 in t3.children(e2) or not e5 in t3.children(e3)
  
  t2.merge t3, before: e4
  roots = t2.roots()
  throw new Error 12 if roots.length != 3
  throw new Error 13 if e4 not in roots or e1 not in roots or e2 not in roots or e3 in roots
  throw new Error 14 if e3 not in t2.children(e2) or e5 not in t2.children(e3)