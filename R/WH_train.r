#'
#' Train weights for WH
#' 
#' Train weights for WH and output weight vector
#'
#' @param X a list of k number of input data, X[[1]] ... X[[k]]. The ith data have sequence information as phyDat format in X[[i]][[1]], and tree information in X[[i]][[2]] as phylo format.
#'
#' @return a weight vector
#'
#' @author Il-Youp Kwak (ikwak2@cau.ac.kr)
#' 
#' @export
#'
WH_train <- function(X){
    WHfit <- function( Wdropout1, Wdropout2, Wothers ) {
        
        InfoW = rep(1,7)
        InfoW[1] = Wdropout1
        InfoW[2] = 1
        InfoW[3] = Wdropout2
        InfoW[4:55] = Wothers
        
        ds = NULL
        for(i in 1:length(X)){
            D_wh = dist_weighted_hamming(X[[i]][[1]], InfoW, dropout = FALSE)
            tree_wh = fastme.bal(D_wh)
            ds = c(ds, -RF.dist(tree_wh, X[[i]][[2]], normalize = TRUE) )
        }    
        
        result = list( Score = mean(ds), Pred = 0 )
        return(result)
        
    }
    
    search_bound <- list(Wdropout1 = c(0.1,2.5),
                         Wdropout2 = c(0.1,2.5),
                         Wothers = c(1, 10)  )
    
    search_grid <- data.frame(Wdropout1 = runif(10, 0.1, 2.5),
                              Wdropout2 = runif(10, 0.1, 2.5),
                              Wothers = runif(10, 1, 10))
    
    bayes_WH <- BayesianOptimization(FUN = WHfit, bounds = search_bound,
                                     init_points = 0, init_grid_dt = search_grid,
                                     n_iter = 20, acq = "ucb")
    
    InfoW = rep(1,7)
    InfoW[1] = bayes_WH$Best_Par['Wdropout1']
    InfoW[2] = 1
    InfoW[3] = bayes_WH$Best_Par['Wdropout2']
    InfoW[4:55] = bayes_WH$Best_Par['Wothers']
    
    InfoW
}

