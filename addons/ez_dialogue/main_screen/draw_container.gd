extends GraphEdit

# Centers the graph given the node name.
func center_on_node(diag_node: DialogueNode):
	scroll_offset = (diag_node.position*zoom - Vector2(size.x / 2,  size.y / 2))
