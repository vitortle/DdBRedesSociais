# 
# install.packages('getURL')
# install.packages('httpuv')
# install.packages('RCurl')
# install.packages('rCharts')

require(httr)
require(devtools)
library(scales)
library('getURL')
library('httpuv')
library('RCurl')
library('jsonlite')
library('ggplot2')
library('RMySQL')
library('base')
require(httr)

# token<-'1073380367.858e864.5f9ad96792634b52b81ef0c3edc9a53f'

full_url <- oauth_callback()
full_url <- gsub("(.*localhost:[0-9]{1,5}/).*", x=full_url, replacement="\\1")
print(full_url)

#preparação da API
app_name <- "DiarioAPP"
client_id <- "ef9689c1912e439b8c76a7b6a3ca0482"
client_secret <- "3558f495a37d4f4a88745df6506208b1"
scope = 'public_content'
instagram <- oauth_endpoint(
  authorize = "https://api.instagram.com/oauth/authorize",
  access = "https://api.instagram.com/oauth/access_token")
myapp <- oauth_app(app_name, client_id, client_secret)
ig_oauth <- oauth2.0_token(instagram, myapp,scope=scope, type = "application/x-www-form-urlencoded",cache=FALSE)
tmp <- strsplit(toString(names(ig_oauth$credentials)), '"')
token <- tmp[[1]][4]

#get dos dados do usuário e dos posts
user_info <- rjson::fromJSON(getURL(paste('https://api.instagram.com/v1/users/self/?access_token=',token,sep="")))
received_profile <- user_info$data$id
media <- rjson::fromJSON(getURL(paste('https://api.instagram.com/v1/users/self/media/recent/?access_token=',token,sep="")))

#conexão com o banco
conexao = dbConnect(MySQL(), user='root', host="127.0.0.1", password="root", dbname="diariodebordodb")
q<-"SELECT count(id_self) FROM self;"
query = dbSendQuery(conexao,q)
dados = fetch(query, n = -1)

#ETL self
df_user=NULL
dt_captura<-strptime(format(Sys.time(), "%Y-%m-%d %X"), "%Y-%m-%d %I:%M:%S %p") 
num_seguidores<-as.numeric(user_info$data$counts$followed_by)
num_seguindo<-user_info$data$counts$follows
num_publicacoes<-user_info$data$counts$media
id_instagram<-user_info$data$id
des_nome<-user_info$data$full_name
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
  df_post$des_user_id[i]<-media$data[[i]]$user$id
  df_post$des_username[i]<-media$data[[i]]$user$username
  df_post$url_imagem[i]<-media$data[[i]]$images$standard_resolution$url
  df_post$dt_criacao[i] <- toString(as.POSIXct(as.numeric(media$data[[i]]$created_time), origin="1970-01-01"))
  df_post$des_descricao[i]<-media$data[[i]]$caption$text
  df_post$num_likes[i]<-media$data[[i]]$likes$count
  df_post$num_comentario[i]<-media$data[[i]]$comments$count
  df_post$des_tipo[i]<-media$data[[i]]$type
  df_post$url_post[i]<-media$data[[i]]$link
  j=1
  while(j<=length(media$data[[i]]$tags)){
    id_post<-media$data[[i]]$id
    conteudo_tag<-media$data[[i]]$tags[j]
    df_tags<-rbind(df_tags, cbind(id_post, conteudo_tag))
    j=j+1
  }
}
df_post<-data.frame(df_post)
df_tags<-data.frame(df_tags)

dbWriteTable(conexao, name = "self", value = df_user, append=TRUE, row.names=F)
dbWriteTable(conexao, name = "post", value = df_post, append=T, row.names=F)
dbWriteTable(conexao, name = "tag", value = df_tags, append=T, row.names=F)

