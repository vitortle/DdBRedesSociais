
r = getOption("repos")
r["CRAN"] = "http://cran.us.r-project.org"
options(repos = r)

list.of.packages <- c("DBI","RMySQL", "httr", "devtools", 'RCurl', 'jsonlite', 'ggplot2', 'base','rjson')
new.packages <- list.of.packages[!(list.of.packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)

require(httr)
require(devtools)
#library('getURL')
library('httpuv')
library('RCurl')
library('jsonlite')
library('ggplot2')
library('DBI')
library('RMySQL')
library('base')
library('rjson')

full_url <- oauth_callback()
full_url <- gsub("(.*localhost:[0-9]{1,5}/).*", x=full_url, replacement="\\1")
print(full_url)

#API config
source('C:/Users/vitor/Documents/Diario de bordo/Midias sociais/Dados/dados_user.r') 
#for security reasons, I put my credentials on a separate file.
#you must create a new R file and fill out 3 variables. They are:
#app_name = 'YouAppName'
#client_id = 'YourClientId'
#client_secret = 'YourClientSecret'
#### If you want to write the data from the API in a Database, you must fill out these variables:
# user='YourUser'
# host='YoutHost'
# password='YourPassword'
# dbname='YourSchemaName'
# scope = 'public_content'
# instagram <- oauth_endpoint(
#   authorize = "https://api.instagram.com/oauth/authorize",
#   access = "https://api.instagram.com/oauth/access_token")
# myapp <- oauth_app(app_name, client_id, client_secret)
# ig_oauth <- oauth2.0_token(instagram, myapp,scope=scope, type = "application/x-www-form-urlencoded",cache=FALSE)
# tmp <- strsplit(toString(names(ig_oauth$credentials)), '"')
#token <- tmp[[1]][4]

#get data from user and posts
user_info <- rjson::fromJSON(getURL(paste('https://api.instagram.com/v1/users/self/?access_token=',token,sep="")))
received_profile <- user_info$data$id
media <- rjson::fromJSON(getURL(paste('https://api.instagram.com/v1/users/self/media/recent/?access_token=',token,sep="")))

#Database connection
conexao = dbConnect(MySQL(), user=user, host=host, password=password, dbname=dbname)

#ETL self
df_user=NULL
dt_captura<-strptime(format(Sys.time(), "%Y-%m-%d %X"), "%Y-%m-%d %I:%M:%S %p") 
num_seguidores<-as.numeric(user_info$data$counts$followed_by)
num_seguindo<-user_info$data$counts$follows
num_publicacoes<-user_info$data$counts$media
id_instagram<-user_info$data$id
des_nome<-user_info$data$full_name
Encoding(des_nome)<-"UTF-8"
des_bio<-user_info$data$bio
ft_profile<-user_info$data$profile_picture
des_username<-user_info$data$username
df_user<-cbind(num_seguidores, num_seguindo, num_publicacoes, id_instagram, des_nome,
               des_bio, ft_profile, des_username)
df_user<-data.frame(df_user)

#posts

df_post<-NULL
df_tags<-NULL
g=1
for(i in 1:length(media$data))
{
  df_post$des_post_id_ig[i]<-media$data[[i]]$id
  df_post$num_user_id[i]<-media$data[[i]]$user$id
  df_post$des_username[i]<-media$data[[i]]$user$username
  df_post$url_imagem[i]<-media$data[[i]]$images$standard_resolution$url
  df_post$dt_criacao[i] <- toString(as.POSIXct(as.numeric(media$data[[i]]$created_time), origin="1970-01-01"))
  df_post$des_descricao[i]<-media$data[[i]]$caption$text
  df_post$num_likes[i]<-media$data[[i]]$likes$count
  df_post$num_comentarios[i]<-media$data[[i]]$comments$count
  df_post$des_tipo[i]<-media$data[[i]]$type
  df_post$url_post[i]<-media$data[[i]]$link
  j=1
  while(j<=length(media$data[[i]]$tags)){
    des_post_id_ig<-media$data[[i]]$id
    conteudo_tag<-media$data[[i]]$tags[j]
    df_tags<-rbind(df_tags, cbind(des_post_id_ig, conteudo_tag))
    j=j+1
  }
}
df_post<-data.frame(df_post)
df_tags<-data.frame(df_tags)

dbWriteTable(conexao, name = "self", value = df_user, append=TRUE, row.names=F, enconding='UTF-8')
dbWriteTable(conexao, name = "post", value = df_post, append=T, row.names=F)
dbWriteTable(conexao, name = "tag", value = df_tags, append=T, row.names=F)

dbDisconnect(conexao)
