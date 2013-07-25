trello-fogbugz-wiki
===================

This script copies Trello board to the fogbugz wiki as an article

To use the script copy the following values in the Constants module

1) Fogbugz Installation URL and API Endpoint
2) Fogbugz API Token (http://fogbugz.stackexchange.com/questions/900/how-do-i-get-an-xml-api-token)
3) The Wiki Article where you wanted the trello board contents to be copied
4) Title
5) Trello API Keys, Secret and Application Token (https://trello.com/1/appKey/generate)
6) SMTP Server details - You can remove the code to send an email if that is not required

Dependent Gems

Trello
Json
net/http
net/smtp (If Email functionality is required)
