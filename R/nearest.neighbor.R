#' Extract the distance to each nearest neighbor for each cell-type
#'
#' @param x IrisSpatialFeatures ImageSet object
#' @param min_num_cells Minimum number of cell that a coordinate needs to have in order to calculate the statistics (Default: 10)
#' @param ... Additional arguments
#'
#' @return distance to nearest neighbor for each
#'
#' @docType methods
#' @export
#'
#' @examples
#'
#' #loading pre-read dataset
#' dataset <- IrisSpatialFeatures_data
#' extract_nearest_neighbor(dataset)
#'
#' @rdname extract_nearest_neighbor
setGeneric("extract_nearest_neighbor", function(x, ...)
    standardGeneric("extract_nearest_neighbor"))

#' @rdname extract_nearest_neighbor
#' @aliases extract.nearest.neighbor,ANY,ANY-method
setMethod(
    "extract_nearest_neighbor",
    signature = "ImageSet",
    definition = function(x, min_num_cells = 10) {
        all_levels <- x@markers
        x@nearest_neighbors <- lapply(x@samples,
                                      nearest_neighbor_sample,
                                      all_levels,
                                      min_num_cells)
        return(x)
    }
)

setGeneric("nearest_neighbor_sample", function(x, ...)
    standardGeneric("nearest_neighbor_sample"))
setMethod(
    "nearest_neighbor_sample",
    signature = "Sample",
    definition = function(x, all_levels, min_num_cells) {
        res <-
            lapply(x@coordinates,
                   nearest_neighbor_coord_raw,
                   all_levels,
                   min_num_cells)

        means <- lapply(res, function(x)
            x$means)
        vars <- lapply(res, function(x)
            x$vars)
        nums <- lapply(res, function(x)
            x$nums)

        #collapse the different coordinates
        means <- collapseMatrices(means, rowMeans)
        vars <- collapseMatrices(vars, rowMeans)
        nums <- collapseMatrices(nums, rowSums)

        #there is a special case where there is only 1 cell of a type
        #this leads to an NA variance. In this case the means are set to NA as well
        means[is.na(vars)] <- NA

        #calculate the standard error on the combined coordinates
        ses <- sqrt(vars) / sqrt(nums)
        return(list(means = means, SE = ses))
    }
)

setGeneric("nearest_neighbor_coord_raw", function(x, ...)
    standardGeneric("nearest_neighbor_coord_raw"))
setMethod(
    "nearest_neighbor_coord_raw",
    signature = "Coordinate",
    definition = function(x, all_levels, min_num_cells) {
        ppp <- x@ppp
        res <-
            lapply(all_levels, getToNeighbors, all_levels, ppp, min_num_cells)
        means <- t(sapply(res, function(x)
            x['means', ]))
        vars <- t(sapply(res, function(x)
            x['vars', ]))
        nums <- t(sapply(res, function(x)
            x['nums', ]))

        rownames(nums) <-
            rownames(means) <- rownames(vars) <- colnames(means)

        #in some cases there are not all samples represented
        means[!is.finite(means)] <- NA
        vars[!is.finite(vars)] <- NA
        nums[!is.finite(nums)] <- NA

        return(list(
            means = means,
            vars = vars,
            nums = nums
        ))
    }
)


#' @importFrom spatstat nncross
#' @importFrom stats var
getNearestNeighbor <- function(from, to, ppp, min_num_cells) {
    if (sum(ppp$marks == from) < min_num_cells |
        sum(ppp$marks == to) < min_num_cells) {
        dis <- NA
    } else{
        dis <- nncross(ppp[ppp$marks == from, ], ppp[ppp$marks == to, ])[, 1]
    }
    means <- mean(dis)
    vars <- var(dis)
    nums <- sum(ppp$marks == from)
    return(c(
        means = means,
        vars = vars,
        nums = nums
    ))
}

getToNeighbors <- function(to, classes, ppp, min_num_cells) {
    res <- sapply(classes, getNearestNeighbor, to, ppp, min_num_cells)
    return(res)
}

################################################################
##### Nearest Neighbors getters


#' Get the nearest neighbor for each cell-type
#'
#' @param x An IrisSpatialFeatures ImageSet object
#' @param ... Additional arguments
#' @return Nearest neighbor for each cell-type
#'
#' @docType methods
#' @export
#'
#' @examples
#' #loading pre-read dataset
#' dataset <- IrisSpatialFeatures_data
#' dataset <- extract_nearest_neighbor(dataset)
#' get_all_nearest_neighbors(dataset)
#'
#' @rdname get_all_nearest_neighbors
setGeneric("get_all_nearest_neighbors", function(x, ...)
    standardGeneric("get_all_nearest_neighbors"))

#' @rdname get_all_nearest_neighbors
#' @aliases get_all_nearest_neighbors,ANY,ANY-method
setMethod(
    "get_all_nearest_neighbors",
    signature = "ImageSet",
    definition = function(x) {
        return(x@nearest_neighbors)
    }
)

#' Get the nearest neighbor for a specified cell-type
#'
#' @param x An IrisSpatialFeatures ImageSet object
#' @param marker Cell type for which the nearest neighbor should be calculated
#' @param ... Additional arguments
#' @return nearest neighbors for the specified cell-type
#'
#' @export
#' @rdname get_nearest_neighbors
#' @examples
#' #' #loading pre-read dataset
#' dataset <- IrisSpatialFeatures_data
#' dataset <- extract_nearest_neighbor(dataset,min_num_cells=2)
#' get_nearest_neighbors(dataset,"SOX10+ PDL1+")
#'
setGeneric("get_nearest_neighbors", function(x, ...)
    standardGeneric("get_nearest_neighbors"))

#' @rdname get_nearest_neighbors
#' @aliases get_nearest_neighbors,ANY,ANY-method
setMethod(
    "get_nearest_neighbors",
    signature = "ImageSet",
    definition = function(x, marker) {
        if (!marker %in% x@markers) {
            stop(paste('There is no celltype: ', marker))
        }

        nn <-
            sapply(x@nearest_neighbors, function(x, y)
                x$means[, y], marker)
        se <-
            sapply(x@nearest_neighbors, function(x, y)
                x$SE[, y], marker)
        return(list(mean = nn, SE = se))
    }
)

###############################################################################################################
##################################### Nearest neighbor plotting functions
###############################################################################################################

#' Plot average nearest neighbor barplots for two cell types. This measurement is not symmetric, so if 'from' and 'to' are switched it will result in different results.
#' For the 'to' parameter this function allows a cell-type without '+' or '-' in the end. Indicating that the distances from the first cell-type should be calculated
#' against both '+/-' and a paired t-test should be calculated. For example we want to calculate the average distance between SOX10 PDL1+ melanoma cells against
#' both CD8 PD1+ and CD8 PD1- cells, the 'CD8 PD1' would be speficified as 'to' parameter, 2 distances would be calculated for each sample and a two-sided paired t-test calculated
#' to test for significant differences.
#'
#' @param x IrisSpatialFeatures ImageSet object.
#' @param from Cell-type from which the nearest neighbor is calculated.
#' @param to Cell-type to which the nearest neighbor is calculated.
#' @param ttest Flag indicating whether a paired t-test should be calculated. (default: TRUE)
#' @param transposed Switches 'from' and 'to' cell-type. This way the (default: FALSE)
#' @param remove_NAs dont plot samples with less than min cells
#' @param use_pixel show the distances in pixels or micrometers (default: FALSE)
#' @param ... Additional arguments.
#' @return plot average nearest neighbor barplots for two cell types
#'
#' @importFrom graphics barplot
#' @importFrom graphics mtext
#' @importFrom stats t.test
#' @docType methods
#' @export
#' @rdname plot_nearest_neighbor
#' @examples
#'
#' #loading pre-read dataset
#' dataset <- IrisSpatialFeatures_data
#' dataset <- extract_nearest_neighbor(dataset)
#' p <- plot_nearest_neighbor(dataset,'CD8+ PD1+','SOX10+ PDL1')
#'
setGeneric("plot_nearest_neighbor", function(x, ...)
    standardGeneric("plot_nearest_neighbor"))

#' @rdname plot_nearest_neighbor
#' @aliases plot_nearest_neighbor,ANY,ANY-method
setMethod(
    "plot_nearest_neighbor",
    signature = "ImageSet",
    definition = function(x,
                          from,
                          to,
                          ttest = TRUE,
                          transposed = FALSE,
                          remove_NAs = FALSE,
                          use_pixel = FALSE) {
        marker_names <- x@markers

        #grab the relevant markers
        comp <- grep(to, marker_names, fixed = TRUE)

        if (length(comp) == 0 || !from %in% marker_names) {
            stop('One or both selected markers are not included in the dataset')
        }

        #drop distances to self
        comp <- comp[!marker_names[comp] %in% from]

        x.mean <-
            extractNNVals(x@nearest_neighbors, 'means', from, comp[1], transposed)
        x.se <-
            extractNNVals(x@nearest_neighbors, 'SE', from, comp[1], transposed)

        if (length(comp) > 1) {
            y.mean <-
                extractNNVals(x@nearest_neighbors, 'means', from, comp[2], transposed)
            y.se <-
                extractNNVals(x@nearest_neighbors, 'SE', from, comp[2], transposed)
            current.mean <- (t(cbind(x.mean, y.mean)))
            #print(current.mean)
            current.se <- (t(cbind(x.se, y.se)))
        } else{
            current.mean <- t(x.mean)
            current.se <- t(x.se)
        }

        # figure out whether to use px or um
        if (!use_pixel){
            #bring measurements into micrometers
            current.mean <- current.mean * x@microns_per_pixel
            current.se <- current.se * x@microns_per_pixel
            unit <- 'um'
        } else {
            unit <- 'px'
        }

        #remove NA values
        if (remove_NAs){
            drop <- colSums(is.na(current.mean)) > 0
            current.mean <- current.mean[,!drop]
            current.se <- current.se[,!drop]
        }else{
            current.se[is.na(current.mean)] <- 0
            current.mean[is.na(current.mean)] <- 0
        }

        max_idx <- which.max(rowSums(current.mean))
        ord <- order(current.mean[max_idx, ], decreasing = TRUE)
        current.mean <- current.mean[, ord]
        current.se <- current.se[, ord]

        #Fixing the legend for the plot
        if (length(comp) == 1) {
            ext <- ''
            leg <- marker_names[comp]
            COLS <- c("lightgrey")
        } else{
            ext <- '+/-'
            leg <- c(marker_names[comp[1]],
                     marker_names[comp[2]])
            COLS <- c("lightgrey", "black")
        }
        label <- buildLabel(from, to, ext, transposed)
        ylab <- paste0("Avg. distance to NN (",unit,")")
        bp <- barplot(
            current.mean,
            main = label,
            xlab = "",
            ylab = ylab,
            col = COLS,
            legend = leg,
            ylim = c(0, max(current.mean) + max(current.se)),
            las = 2,
            beside = TRUE
        )

        if (length(comp) > 1) {
            # Add a check for NA values if there is an NA value in one row, we need it in the other row.
            #print(current.mean)
            plotSE(bp, current.mean, current.se, 1)
            plotSE(bp, current.mean, current.se, 2)
        } else{
            bp <- t(bp)
            current.mean <- t(current.mean)
            current.se <- t(current.se)
            plotSE(bp, current.mean, current.se, 1)
        }
        #paired t test to test for significance
        if (ttest & length(comp) > 1) {
            current.mean <- current.mean[,colSums(current.mean != 0)==2]
            current.se <- current.se[,colSums(current.se !=0 )==2]
            pval <-
                t.test(current.mean[1, ], current.mean[2, ], paired = TRUE)$p.value
            mtext(paste('Paired t-test:', format(pval, digits = 4)), 3)
        } else{
            pval <- NA
        }
        return(list(
            means = current.mean,
            ses = current.se,
            pval = pval,
            label = label,
            ylab = ylab
        ))
    }
)

#' @importFrom graphics arrows
plotSE <- function(bp, current.mean, current.se, idx) {
    arrows(
        bp[idx, ],
        current.mean[idx, ] + current.se[idx, ],
        bp[idx, ],
        current.mean[idx, ],
        angle = 90,
        code = 3,
        length = 0.02,
        col = 'black'
    )
}

#extract the marker pos/neg values across the samples
extractNNVals <- function(mat, val, from, to, transposed) {
    if (transposed) {
        dest <- from
        src <- to
    } else{
        dest <- to
        src <- from
    }
    return(sapply(mat, function(x, y, z)
        x[[val]][z, y], src, dest))
}

#generate the label of the plot
buildLabel <- function(from, to, ext, transposed) {
    if (transposed) {
        label <- paste('Distance from', to, ext, 'to', from)
    } else{
        label <- paste('Distance from', from, 'to', to, ext)
    }
    return(label)
}

###############################################################################################################
##################################### ray plots
###############################################################################################################

#' Plot nearest neighbor ray plots for each samples
#'
#' @param x An IrisSpatialFeatures ImageSet object
#' @param from_type Cell type from which the rays are drawn
#' @param to_type Cell type to which the rays are drawn
#' @param from_col Color for the 'from' cell-type (Default: '#EE7600')
#' @param to_col Color for the 'to' cell-type  (Default: '#028482')
#' @param format Format of the output file, can be '.pdf' or '.png' (Default: '.pdf')
#' @param plot_dir Directory in which the images are written (Default: './')
#' @param lineColor Color of the rays (Default: '#666666')
#' @param use_pixel use pixels instead of micrometer for distance measurements (default: FALSE)
#' @param height Height of the pdf. (Default: 7)
#' @param width Width of the pdf. (Default: 10)
#' @param ... Additional arguments.
#' @return nearest neighbor ray plots
#'
#' @docType methods
#' @export
#'
#' @importFrom spatstat superimpose
#' @rdname neighbor_ray_plot
#' @examples
#'
#' #loading pre-read dataset
#' dataset <- IrisSpatialFeatures_data
#' dataset <- extract_nearest_neighbor(dataset)
#' get_nearest_neighbors(dataset,"SOX10+ PDL1+")
#' plot_dir <- file.path('./ray_plots')
#' if (!file.exists(plot_dir)){
#'  dir.create(file.path(plot_dir))
#' }
setGeneric("neighbor_ray_plot", function(x, ...)
    standardGeneric("neighbor_ray_plot"))

#' @rdname neighbor_ray_plot
#' @aliases neighbor.ray.plot,ANY,ANY-method
setMethod(
    "neighbor_ray_plot",
    signature = "ImageSet",
    definition = function(x,
                          from_type,
                          to_type,
                          from_col = '#EE7600',
                          to_col = '#028482',
                          format = '.pdf',
                          plot_dir = './',
                          lineColor = '#666666',
                          use_pixel = FALSE,
                          height = 7,
                          width = 10) {
        #generate the mapping directory
        #out_dir <- file.path(getwd(), plot_dir)
        out_dir <- plot_dir
        if (!file.exists(out_dir)) {
            dir.create(out_dir, showWarnings = FALSE)
        }

        #generate ray plots for each sample
        lapply(
            x@samples,
            neighbor_ray_plot_sample,
            from_type,
            to_type,
            from_col,
            to_col,
            out_dir,
            format,
            lineColor,
            use_pixel,
            height,
            width,
            x@microns_per_pixel
        )
    }
)

setGeneric("neighbor_ray_plot_sample", function(x, ...)
    standardGeneric("neighbor_ray_plot_sample"))
setMethod(
    "neighbor_ray_plot_sample",
    signature = "Sample",
    definition = function(x,
                          from_type,
                          to_type,
                          from_col,
                          to_col,
                          out_dir,
                          format,
                          lineColor,
                          use_pixel,
                          height,
                          width,
                          microns_per_pixel) {
        lapply(
            x@coordinates,
            neighbor_ray_plot_coord,
            x@sample_name,
            from_type,
            to_type,
            from_col,
            to_col,
            out_dir,
            format,
            lineColor,
            use_pixel,
            height,
            width,
            microns_per_pixel
        )
    }
)


#' @importFrom spatstat nncross
#' @importFrom graphics legend
#' @importFrom graphics par
#' @importFrom graphics plot
#' @importFrom graphics segments
#' @importFrom grDevices dev.off
#' @importFrom grDevices pdf
#' @importFrom grDevices png
setGeneric("neighbor_ray_plot_coord", function(x, ...)
    standardGeneric("neighbor_ray_plot_coord"))
setMethod(
    "neighbor_ray_plot_coord",
    signature = "Coordinate",
    definition = function(x,
                          samp_name,
                          from_type,
                          to_type,
                          from_col,
                          to_col,
                          out_dir,
                          format,
                          lineColor,
                          use_pixel,
                          height,
                          width,
                          microns_per_pixel) {


        #extract the relevant cells
        if (sum(x@ppp$marks == from_type) > 0 &&
            sum(x@ppp$marks == to_type) > 0) {

            file_stub <- paste0(samp_name, '_', x@coordinate_name)
            if (format == '.pdf') {
                pdf(
                    file = file.path(out_dir, paste0(file_stub, '.pdf')),
                    width = width,
                    height = height
                )
            } else if (format == '.png') {
                png(file.path(out_dir, paste0(file_stub, '.png')),
                    width = 800,
                    height = 600)
            }

            rayplot_single_coordinate(x,
                                      from_type,
                                      to_type,
                                      samp_name,
                                      from_col = '#EE7600',
                                      to_col = '#028482',
                                      lineColor = '#666666',
                                      use_pixel = use_pixel,
                                      microns_per_pixel = microns_per_pixel)

            dev.off()
        }
    }
)


#' Plot nearest neighbor ray plots for a single coordinate
#'
#' @param x An Coordinate object
#' @param from_type Cell type from which the rays are drawn
#' @param to_type Cell type to which the rays are drawn
#' @param samp_name Name of the sample
#' @param from_col Color for the 'from' cell-type (Default: '#EE7600')
#' @param to_col Color for the 'to' cell-type  (Default: '#028482')
#' @param lineColor Color for the line (Default: '#666666')
#' @param use_pixel Express units as pixels (Default: FALSE)
#' @param microns_per_pixel Conversion (Default: 0.496)
#' @return a plot
#'
#' @docType methods
#' @export
#'
#' @importFrom spatstat nncross
#' @importFrom spatstat superimpose
#' @importFrom graphics legend
#' @importFrom graphics par
#' @importFrom graphics plot
#' @importFrom graphics segments
#' @importFrom grDevices dev.off
#' @importFrom grDevices pdf
#' @importFrom grDevices png
#' @rdname rayplot_single_coordinate
#' @examples
#'
#' #loading pre-read dataset
#' dataset <- IrisSpatialFeatures_data
#' dataset <- extract_nearest_neighbor(dataset)
#' rayplot_single_coordinate(x = dataset@samples[[1]]@coordinates[[1]],
#'                           samp_name = dataset@samples[[1]]@sample_name,
#'                           from_type = "SOX10+ PDL1+",
#'                           to_type = "CD8+ PD1+")
setGeneric("rayplot_single_coordinate", function(x,
                                                from_type,
                                                to_type,
                                                samp_name='',
                                                from_col= '#EE7600',
                                                to_col= '#028482',
                                                lineColor = '#666666',
                                                use_pixel=FALSE,
                                                microns_per_pixel=0.496)
    standardGeneric("rayplot_single_coordinate"))
#' @rdname rayplot_single_coordinate
setMethod(
    "rayplot_single_coordinate",
    signature = "Coordinate",
    function(x,
                                      from_type,
                                      to_type,
                                      samp_name = '',
                                      from_col = '#EE7600',
                                      to_col = '#028482',
                                      lineColor = '#666666',
                                      use_pixel = FALSE,
                                      microns_per_pixel = 0.496){

    from <- x@ppp[x@ppp$marks == from_type, ]
    to <- x@ppp[x@ppp$marks == to_type, ]

    # figure out whether to use px or um
    if (!use_pixel){
        #bring measurements into micrometers
        from$x <- from$x * microns_per_pixel
        from$y <- from$y * microns_per_pixel
        to$x <- to$x * microns_per_pixel
        to$y <- to$y * microns_per_pixel
        unit <- 'um'
    } else {
        unit <- 'px'
    }

    #get limits
    overlap <- superimpose(from, to)
    xlim <- max(data.frame(overlap)$x)
    ylim <- max(data.frame(overlap)$y)

    #get distances
    dist <- nncross(from, to)
    nearest <- data.frame(cbind(data.frame(from),
                                dist$dist,
                                data.frame(to[dist$which, ])))
    names(nearest) <-
        c('from_x',
          'from_y',
          'from_type',
          'dist',
          'to_x',
          'to_y',
          'to_type')

    #get the colors right
    df <- data.frame(overlap)
    df$cols <- as.character(df$marks)
    df$cols[df$cols == from_type] <- from_col
    df$cols[df$cols == to_type] <- to_col

    par(mar = c(4, 4, 4, 1))
    plot(df$x,
         df$y,
         col = as.character(df$cols),
         pch = 18,
         ylim = rev(range(df$y)),
         ylab = paste0('y (', unit, ')'),
         xlab = paste0('x (', unit, ')'),
         main = paste(samp_name, '-', x@coordinate_name)
    )
    segments(nearest$from_x,
             nearest$from_y,
             nearest$to_x,
             nearest$to_y,
             col = lineColor)
    legend(
        'bottomleft',
        col = c(from_col, to_col),
        legend = c(from_type, to_type),
        pch = 18,
        cex = 0.8
    )
})
