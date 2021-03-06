#' Creates text-based features from a radiology report corpus
#'
#' This function creates N-gram features from a radiology report corpus, where N-gram
#' @param segmented.reports Input data frame with
#' @param id_col The ID column in segmented.reports, defaults to imageid
#' @param text.cols Vector of findings text column names in segmented.reports, defaults to  c("body","impression")
#' @param all.stop.words List of stop words, defaults to English stopword list excluding negation
#' @param finding.dictionary Dictionary object to map findings, defaults to NULL
#' @param docfreq See quanteda::dfm_trim; One of "count", "inverse", "inversemax", "inverseprob", "unary"
#' @param min_doc_prop minimum/maximum values of a feature's document frequency, below/above which features will be removed
#' @param max_doc_prop
#' @param termfreq See quanteda::dfm_trim; One of "count", "prop", "propmax", "logcount", "boolean", "augmented", "logave"
#' @param min_term_freq minimum/maximum values of feature frequencies across all documents, below/above which features will be removed
#' @param max_term_freq Above
#' @param tf_type See quanteda::dfm_weight; One of "count", "prop", "propmax", "logcount", "boolean", "augmented", "logave"
#' @param df_type See quanteda::docfreq; One of "count", "inverse", "inversemax", "inverseprob", "unary"
#' @param n_gram_length Unigram, bigram, or trigram features; defaults to 3 (trigrams)
#' @keywords CreateTextFeatures
#' @import quanteda
#' @export
#' @return A document frequency matrix with each row as a unique report,
#' each column is a feature, and the cells are the counts in the document.
#' @examples
#' CreateTextFeatures(segmented.reports)

CreateTextFeatures = function(segmented.reports,
                               n_gram_length = 1,
                               id_col = "imageid",
                               text.cols = c("findings","impression"),
                               all.stop.words = setdiff(stopwords(), c("no", "not", "nor")),
                               finding.dictionary = NULL,
                               docfreq = "prop",
                               min_doc_prop = 0,
                               max_doc_prop = 1,
                               termfreq = "count",
                               min_term_freq = 1,
                               max_term_freq = NULL,
                               tf_type = "boolean",
                               df_type = "unary"){
  dfm.list <- list()
  ### create feature matrix for each text column
  for(col in 1:length(text.cols)){
    ### create feature matrix
    this.dfm = quanteda::corpus(as.character(segmented.reports[,text.cols[col]]),
                                docnames = segmented.reports[,id_col]) %>%
      quanteda::tokens(.,
                       remove_punct=TRUE,
                       remove_symbols=TRUE,
                       remove_separators=TRUE,
                       split_hyphens=FALSE,
                       remove_url=TRUE) %>%
      quanteda::tokens_ngrams(., n_gram_length) %>%
      quanteda::dfm(., language = "english",
                    tolower = TRUE,
                    stem = TRUE,
                    remove = all.stop.words,
                    thesaurus = finding.dictionary,
                    valuetype = "glob") %>%
      #### remove most frequent and sparse words
      quanteda::dfm_trim(.,
                         min_docfreq = min_doc_prop,
                         max_docfreq = max_doc_prop,
                         docfreq_type = docfreq) %>%
      dfm_tfidf(., scheme_tf = tf_type, # change count to binary
                scheme_df = df_type)
    features = colnames(this.dfm)
    ids = docnames(this.dfm)
    this.dfm.df = data.frame("imageid"=ids)
    for (feature in features) {
      this.dfm.df[,feature] = this.dfm[,feature] %>% as.vector(.)
    }
    colnames(this.dfm.df)[2:ncol(this.dfm.df)] <- paste(toupper(text.cols[col]),
                                                        colnames(this.dfm.df)[2:ncol(this.dfm.df)],
                                                        sep = "_")
    print(dim(this.dfm.df))
    dfm.list[[length(dfm.list) + 1]] <- this.dfm.df
  }
  ## Combine features into the same document feature matrix
  segmented.reports <- do.call(left_join, dfm.list)
  return(segmented.reports)
}

