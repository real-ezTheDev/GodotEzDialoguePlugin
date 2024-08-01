extends GraphEdit

# Centers the graph given the node name.
func center_on_node(diag_node: DialogueNode):
	scroll_offset = diag_node.position*zoom - (size/2)

func get_center_of_graph_position() -> Vector2 :
	return (scroll_offset + (size/2))/zoom
