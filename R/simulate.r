#' simulate
#'
#' Adoped from https://github.com/elifesciences-publications/CRISPR_recorders_sims/blob/master/MATLAB_sims/GESTALT_30hr_1x_simulation.m
#'
simulate <- function(
	n_samples = 200, # number of samples to simulate 
	n_targets = 200,  	# number of targets 
	mutation_prob = 0.03,   # mutation rate (a scalar)
	division = 16L, # number of cell divisons
	alphabets = NULL,
	outcome_prob = NULL, # outcome probability vector
	dropout = TRUE
){

	num_states <- length(alphabets)
	DEFAULT <- '0'
	DROPOUT <- '-'
    
	if (is.null(outcome_prob))
		stop('outcome_prob must be specified')

	tree <- random_tree(n_samples = n_samples, division = division)

	ancestor <- 1
	x <- matrix(DEFAULT, nrow = 1, ncol = n_targets, dimnames = list(ancestor %>% get_node_names(), NULL))	# the ancestor sequence
	h <- 1	# a unit time
	while (h < division){

		pairs <- tree %>% filter(height == h) 	# parent-child pairs at level h
		parents <- pairs[, 1] %>% get_node_names()
		children <- pairs[, 2] %>% get_node_names()
		xc <- x[parents, , drop = FALSE]	# the states of the children cells
		rownames(xc) <- children

		for (i in 1:nrow(pairs)){ # for each child

			mutation_site <- runif(n_targets) < mutation_prob & xc[i, ] == DEFAULT	# sampling mutation site
			n_mut <- sum(mutation_site)

			if (n_mut > 0){
				xc[i, mutation_site] <- sample(alphabets, n_mut, replace = TRUE, prob = outcome_prob)
				if (n_mut > 1 && dropout){
					# find all pairs of mutation sites within 20 bp
					p <- expand.grid(from = which(mutation_site), to = which(mutation_site)) %>%
						filter(to - from <= 20 & to - from >= 2)
					if (nrow(p) > 0){
						j <- sample(1:nrow(p), 1)
						from <- p[j, 'from'] + 1
						to <- p[j, 'to'] - 1
						xc[i, from:to] <- DROPOUT
					}
				}
			}
		}

		x <- rbind(x, xc)
		h <- h + 1
	}

	num_nodes <- 2^division - 1
	node_names <- (1:num_nodes) %>% get_node_names()
	A <- sparseMatrix(
		i = tree[, 'from'], 
		j = tree[, 'to'], 
		dims = c(num_nodes, num_nodes),
		dimnames = list(node_names, node_names)
	)
	A <- A[rownames(x), rownames(x)]

	g <- A %>% as('dgCMatrix') %>% graph.adjacency()

	x <- x %>% phyDat(type = 'USER', levels = alphabets)

	new('lineage_tree', 
		x = x, 
		graph = g, 
		outcome_prob = outcome_prob, 
		alphabets = alphabets,
		division = division,
		n_samples = n_samples,
		n_targets = n_targets,
		dropout = dropout
	)

} # simulate

#' random_tree
#'
random_tree <- function(n_samples, division = 16L){

	ancestor <- 1	# ancestor index
	num_nodes <- 2^division - 1	# number of total nodes in the binary tree
	k <- 2:num_nodes
	edges <- cbind(from = k %/% 2, to = k)	# a binary tree
	edges <- edges[order(edges[, 'to']), ]	# so that edge `from | to` is simply edges[to - 1, ]

	leaves <- 2^(division - 1):(2^division - 1)	# leaf index
	sampled_leaves <- sample(leaves, n_samples)	# leaves to keep

	sampled_edges <- list()
	h <- division - 1	# leaf level
	sampled_edges[[h]] <- edges[sampled_leaves - 1, ]
	while (h > 1){
		to <- unique(sampled_edges[[h]][, 'from'])
		sampled_edges[[h - 1]] <- edges[to - 1, ]
		h <- h - 1
	}

	height <- rep(seq_len(division  - 1), sapply(sampled_edges, nrow))
	sampled_edges <- do.call('rbind', sampled_edges)
	data.frame(sampled_edges, height = height)
} # random_tree


#' sample_outcome_prob
#'
sample_outcome_prob <- function(alphabets){

	num_states <- length(alphabets)
	rvs <- rgamma(num_states - 2, shape = 0.1, scale = 2)
	rvs <- rvs / sum(rvs)
	rvs <- sort(rvs, decreasing = TRUE)

	# the target mutation rate
	outcome_prob <- c(0, 0, rvs)
	names(outcome_prob) <- alphabets
	outcome_prob

} # sample_outcome_prob

#' get_node_names
#'
get_node_names <- function(x) sprintf('node_%s', str_pad(x, nchar(2^21), pad = '0'))


