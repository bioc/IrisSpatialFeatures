% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/read.functions.R
\docType{methods}
\name{read_raw}
\alias{read_raw}
\alias{read_raw,character-method}
\alias{read_raw,ANY,ANY-method}
\title{Read inForm output and store it in an IrisSpatialFeatures ImageSet object.}
\usage{
read_raw(path, label_fix = list(), format = "Vectra", dir_filter = "",
  read_nuc_seg_map = FALSE, MicronsPerPixel = 0.496,
  invasive_margin_in_px = 100, readMasks = TRUE, ignore_scoring = FALSE,
  read_only_relevant_markers = TRUE)

\S4method{read_raw}{character}(path, label_fix = list(), format = "Vectra",
  dir_filter = "", read_nuc_seg_map = FALSE, MicronsPerPixel = 0.496,
  invasive_margin_in_px = 100, readMasks = TRUE, ignore_scoring = FALSE,
  read_only_relevant_markers = TRUE)
}
\arguments{
\item{path}{Directory that contains the raw files}

\item{label_fix}{List of length 2 character vector that is used to fix filenames.}

\item{format}{Output format: Currently only "Vectra" and "Mantra" are supported.}

\item{dir_filter}{Filter to select only certain directory names.}

\item{read_nuc_seg_map}{Flag indicating whether the nuclear map should be read.}

\item{MicronsPerPixel}{Length of one pixel. Default: 0.496, corresponding to a 20x Mantra/Vectra images}

\item{invasive_margin_in_px}{The width of the invasive margin in pixels}

\item{readMasks}{Flag indicating whether the "_Tumor.tif" and "_Invasive_Margin.tif" should be read (default: True)}

\item{ignore_scoring}{Flag indicating whether the scoring file should be ignored (default: False)}

\item{read_only_relevant_markers}{Flag that indicates whether all read inform output should be kept or only the relevant markers}
}
\value{
IrisSpatialFeatures ImageSet object.
}
\description{
Read inForm output and store it in an IrisSpatialFeatures ImageSet object.
}
\examples{
 raw_data <- read_raw(path=system.file("extdata", package = "IrisSpatialFeatures"),
                      format='Mantra')
}
