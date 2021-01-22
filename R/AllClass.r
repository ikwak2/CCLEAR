setOldClass('phyDat')
setOldClass('phylo')
setOldClass('igraph')
setOldClass('kerastools.model.RModel')
setOldClass('tf_dataset')
setOldClass('tensorflow.tensor')

setClass(
	'lineage_tree_config',
	representation(
		outcome_prob = 'numeric',
		alphabets = 'character',
		division = 'numeric',
		n_targets = 'numeric',
		deletion = 'logical',
		dropout_prob = 'numeric',
		mutation_prob = 'numeric',
		frequency = 'numeric',
		dropout_character = 'character',
		default_character = 'character',
		deletion_character = 'character',
		root = 'character'
	),
	prototype = list(
		alphabets = c('*', '0', '-', letters, LETTERS),
		outcome_prob = rep(0, 3 + length(letters) + length(LETTERS)),
		dropout_character = '*',
		default_character = '0',
		deletion_character = '-'
	)
)

setClass(
	'LineageTree',
	representation(
		x = 'phyDat',
		graph = 'igraph',
		config = 'lineage_tree_config'
	)
)

setClass(
	'kmer_summary',
	representation(
		df = 'data.frame',
    k = 'numeric',
		reps = 'numeric',
		alphabets = 'character',
		kmers = 'character',
		max_distance = 'numeric',
		config = 'lineage_tree_config'
	)
)

setClass('Model', slot = c(model = 'kerastools.model.RModel'))
setClass('SimDistModel', contains = 'Model')

#' LineageTreeList
#'
#' @export
#'
setClass(
	'LineageTreeList',
	contains = 'SimpleList'
)

