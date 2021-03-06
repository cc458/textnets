prep_text_noun_phrases <-function(textdata, groupvar, textvar, 
                                  node_type=c("groups","words"), n_return = 1000,
                                  top_phrases=TRUE, max_ngram_length = 4, 
                                  remove_numbers=FALSE, remove_url=TRUE) {

  #remove URLS
  if (remove_url) {
    textdata[[textvar]]<-stringr::str_replace_all(textdata[[textvar]], "https?://t\\.co/[A-Za-z\\d]+|https?://[A-Za-z\\d]+|&amp;|&lt;|&gt;|RT|https?", "")
  }
  
  #remove numbers
  if (remove_numbers) {
    textdata[[textvar]]<-gsub("\\b\\d+\\b", "",textdata[[textvar]])
  }
  
  #remove extra whitespace
  textdata[[textvar]] <- gsub("\\s+"," ",textdata[[textvar]])
  
  #remove texts that are entirely empty
  message(paste(as.character(nrow(filter(textdata, grepl("^\\s*$", textdata[[textvar]]))))), ' documents were removed because they are empty.')
  
  textdata <- filter(textdata, !grepl("^\\s*$", textdata[[textvar]])) 
  
  textdata<-textdata %>%
    select_(groupvar,textvar)%>%
    #tidy text
    mutate_at(textvar, funs(phrasemachine(., maximum_ngram_length = max_ngram_length))) %>%
    group_by_(groupvar) %>%
    mutate_at(textvar, funs(paste0(unlist(.),collapse=" "))) %>%
    unnest_tokens_("word", textvar)  %>%
    #  #now change names to document and term for consistency
    ungroup


  if (node_type=="groups"){
    #count terms by document
    textdata<-textdata %>%
      rename_(group=groupvar)  %>%
      # # # #count terms by document
      group_by(group) %>%
      count(word, sort = FALSE) %>%
      rename(count=n)
  }
  
  if (node_type=="words"){
    textdata<-textdata %>%
      rename_(group=groupvar)  %>%
      # # # #count terms by group
      group_by(group) %>%
      count(word, sort = FALSE) %>%
      rename(count=n)
  }
  
  # Remove leading and trailing underscores
  mysub <- function(re, x) sub(re, "", x, perl = TRUE)
  textdata <- textdata %>%
    rowwise() %>% 
    mutate(word = mysub("[ _]+$", mysub("^[ _]+", word))) %>%
    ungroup() %>%
    group_by(group, word) %>%
    mutate(count = sum(count)) %>%
    distinct()

  
  # Filter to only the top 1000 phrases
  if (top_phrases==TRUE){
    phrases <- textdata %>%
      filter(grepl("_",word))
    phrases$group <- NULL
    
    phrases <- phrases %>%
      group_by(word) %>%
      summarise(count = sum(count)) %>%
      arrange(desc(count))
    
    if (nrow(phrases) > 1000){
      phrases <- filter(phrases, count >= phrases$count[1000])
    }
    
    textdata <- textdata %>%
      filter(!grepl("_",word) | word %in% phrases$word)
  }
  
  return(textdata)
}



