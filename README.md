# DevOpsBot Web Application

## Solution Overview
![Solution Overview](https://raw.githubusercontent.com/maniSbindra/devOpsBot/master/solution%20overview/DevBot.jpg "Solution Overview")

### Following features have been included in the initial release of devBot which is our DevOps Bot
1. Slack - VSTS task expander : If Visual Studio Team Services (VSTS) project task number is mentioned in the slack channel in format **task #_tasknumber_**, the task expander gives the details of the task along with link to edit the task in VSTS
2. Slack - VSTS build trigger : Authorised users can trigger VSTS builds using the format **#triggerbuild _buildnumber_** 

### integration with other components
1. VSTS : Basic HTTP authentication is used to integrate with VSTS
2. Slack Channel : Slack custom integration with the BOT is used, the slack token provided needs to be specified
3. Build Admin REST API : when build trigger patter is detected this API is called to check if user has permissions to check if user has permissions to trigger builds . Please refer https://github.com/maniSbindra/buildAdminAPI 

## Web App Configuration
### Following Environment Variables / Appsettings are needed for the application
1. SLACK_BOT_TOKEN : Bot custom integration token from slack
2. VSO_USERNAME : VSO username for basic http authentication
3. VSO_PASSWORD : VSO Password for basic http authentication
4. VSO_BASEURL : VSO base url for account
5. DEFAULT_PROJECT : VSO default project to trigger builds
6. BUILD_API_BASE_URL : Build API base url
7. BUILD_API_USER : Build api user name for basic http authentication
8. BUILD_API_PASS : Build api password for basic http authentication


## Other Key Points
### This demo has been built using Node Slack Client
### Node.js Slack Client Library
### node-slack v2.0.0 please read!
