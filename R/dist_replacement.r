setGeneric('dist_replacement', function(x, kmer_summary, ...) standardGeneric('dist_replacement'))

#' dist_replacement
#' 
#' Compute the sequence distance by kmer replacement
#' @param ix nput data in phyDat format
#' @param kmer_summary a kmer_summary object
#' @return a dist object
#' @export
#' @author Wuming Gong (gongx030@umn.edu)
#'
setMethod(
	'dist_replacement',
	signature(
		x = 'phyDat',
    kmer_summary = 'kmer_summary'
	),
	function(x, kmer_summary, k = 2, ...){

    if (kmer_summary@k != 2)
      stop('k must be 2 in kmer_summary')

    dist_kmer_replacement_inference(x, kmer_summary, k)

  }
)


#' dist_kmer_replacement_inference
#' 
#' Compute the sequence distance matrix using inferred kmer replacement matrix 
#'
#' @param x input data in phyDat format
#' @param kmer_summary a kmer_summary object
#' @param k k-mers (default k=2)
#' @return a dist object
#' @author Wuming Gong (gongx030@umn.edu)
#'
dist_kmer_replacement_inference <- function(x, kmer_summary, k = 2){

  log_p_D <- log(get_distance_prior(kmer_summary))

  log_p_AB_D <- kmer_summary %>%
    substr_kmer(k = 1) %>%
    get_replacement_probability()
	log_p_AB_D <- log(log_p_AB_D + 1e-10)

  if (k > 1){
    log_p_B_AD <- get_transition_probability(kmer_summary)
		log_p_B_AD <- log(log_p_B_AD + 1e-10)

	}

	p <- expand.grid(
		from = 1:length(x),
		to = 1:length(x),
    distance = 1:kmer_summary@max_distance
	) %>% 
		filter(from < to)

  # input sequence in BStringSet object
  y <- do.call('paste0', as.data.frame(x %>% as.character())) %>%
    BStringSet()

  sequence_length <- ncol(x %>% as.character())

#  d <- p %>% filter(distance == 1)
#	d$distance <- 0
	p1 <- p %>% filter(distance == 1)

  D <- Matrix(0, nrow = length(x), ncol = length(x), dimnames = list(names(x), names(x)))

  for (start in seq_len(sequence_length - k + 1)){  # for each k-mer segment

		if (start %% 10 == 0){
			flog.info(sprintf('posterior probability | position=%5.d/%5.d', start, sequence_length))
		}

    yi <- substr(y, start, start)

    str_from <- yi[p[, 'from']] %>% 
      factor(kmer_summary@alphabets) %>% 
      as.numeric()

    str_to <- yi[p[, 'to']] %>% 
      factor(kmer_summary@alphabets) %>% 
      as.numeric()

    log_prob <- log_p_AB_D[cbind(str_from, str_to, p$distance)]

    if (k > 1){

      for (i in seq(k - 1)){

        start_i <- start + i - 1

        t1 <- substr(y, start_i, start_i)
        t2 <- substr(y, start_i + 1, start_i + 1)

        str_from <- paste0(t1[p[, 'from']], t1[p[, 'to']]) %>%
          factor(kmer_summary@kmers) %>% 
          as.numeric()

        str_to <- paste0(t2[p[, 'from']], t2[p[, 'to']]) %>%
          factor(kmer_summary@kmers) %>% 
          as.numeric()

        log_prob <- log_prob + log_p_B_AD[cbind(str_from, str_to, p$distance)]

      }
    }

    log_prob  <- log_prob +  log_p_D[p$distance]

    P <- matrix(log_prob, nrow = length(x) * (length(x) - 1) / 2, ncol = kmer_summary@max_distance)
    post <- exp(P - apply(P, 1, logSumExp))

#		di <- rowSums(post %*% Diagonal(x = 1:kmer_summary@max_distance))
#		d$distance <- d$distance + di
		Di <- sparseMatrix(
											       i = p1[, 'from'], 
														       j = p1[, 'to'], 
																	       x = rowSums(post %*% Diagonal(x = 1:kmer_summary@max_distance)),
																				       dims = c(length(x), length(x)),
																							       dimnames = list(names(x), names(x))
														     )
		    D <- D + Di

  }

#	D <- sparseMatrix(
#  	i = d$from,
#		j = d$to,
#		x = d$distance,
#		dims = c(length(x), length(x)),
#		dimnames = list(names(x), names(x))
#	) %>%
#		as.matrix()

  D <- t(D) + D
  D %>% as.dist()

} # dist_kmer_replacement_inference

 
#' get_distance_prior 
#'
#' prior distribution of distance
#'
#' @param x a kmer_summary object
#' @return a probabilistic vector of the distribution of nodal distances
#'
#' @author Wuming Gong (gongx030@umn.edu)
#'
get_distance_prior <- function(x){

  d <- x@df %>%
    ungroup() %>%
    group_by(distance) %>%
    summarize(n = sum(n)) %>%
    mutate(prob = n / sum(n)) %>%
    select(distance, prob)

  prior <- rep(0, x@max_distance)
  prior[d$distance] <- d$prob
  prior

} # get_distance_prior


#' get_transition_probability
#'
#' Compute p(A,X|B,Y,d), the conditional probability of seeing a replacement from A to B
#' given the previous replacement B from Y at nodal distance d
#'
#' @param x a kmer_summary object
#' @return an 3D probabilistic array (kmers by kmers by distances)
#' @export
#'
#' @author Wuming Gong (gongx030@umn.edu)
#'
get_transition_probability <- function(x){

  # conditional transition probability
  d <- x@df %>%
    ungroup() %>%
    mutate(
      from2 = paste0(substr(from, 1, 1), substr(to, 1, 1)),
      to2 = paste0(substr(from, 2, 2), substr(to, 2, 2))
    ) %>%
    mutate(from = from2, to = to2) %>%
    select(from, to, distance, n) %>%
    right_join(
      expand.grid(
        from = x@kmers, 
        to = x@kmers, 
        distance = 1:x@max_distance, 
        stringsAsFactors = FALSE
      ),
      by = c('from', 'to', 'distance')
    ) %>%
    replace_na(list(n = 0))  %>%
    mutate(n = ifelse(from == to, n + 1, n)) %>%
    group_by(distance, from) %>%
    mutate(prob = n / sum(n)) %>%
    select(from, to, distance, prob) %>%
		mutate(
			from = factor(from, x@kmers),
			to = factor(to, x@kmers)
		) %>%
		arrange(distance, to, from)

  array(
    d$prob, 
    dim = c(length(x@kmers), length(x@kmers), x@max_distance),
    dimnames = list(x@kmers, x@kmers, NULL)
  )

} # get_transition_probability



#' get_replacement_probability
#'
#' Compute p(A,B|d), the conditional probability of seeing a replacement of from kmer A to B or vice versa
#'
#' @param x a kmer_summary object
#' @return an 3D probabilistic array (kmers by kmers by distances)
#' @export
#'
#' @author Wuming Gong (gongx030@umn.edu)
#'
get_replacement_probability <- function(x){

  d <- x@df %>% 
    right_join(
      expand.grid(
        from = x@kmers,
        to = x@kmers, 
        distance = 1:x@max_distance, 
        stringsAsFactors = FALSE
      ),
      by = c('from', 'to', 'distance')
    ) %>%
    replace_na(list(n = 0))  %>%
    mutate(n = ifelse(from == to, n + 1, n)) %>%
    group_by(distance) %>%
    mutate(prob = n / sum(n)) %>%
    select(from, to, distance, prob) %>%
		mutate(
			from = factor(from, x@kmers),
			to = factor(to, x@kmers)
		) %>%
		arrange(distance, to, from)

  array(
    d$prob, 
    dim = c(length(x@kmers), length(x@kmers), x@max_distance),
    dimnames = list(x@kmers, x@kmers, NULL)
  )

} # get_replacement_probability


