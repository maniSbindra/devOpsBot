Slack = require '..'
request = require 'request'

token = process.env.SLACK_BOT_TOKEN 
autoReconnect = true
autoMark = true

slack = new Slack(token, autoReconnect, autoMark)

slack.on 'open', ->
  channels = []
  groups = []
  unreads = slack.getUnreadCount()

  # Get all the channels that bot is a member of
  channels = ("##{channel.name}" for id, channel of slack.channels when channel.is_member)

  # Get all groups that are open and not archived 
  groups = (group.name for id, group of slack.groups when group.is_open and not group.is_archived)

  console.log "Welcome to Slack. You are @#{slack.self.name} of #{slack.team.name}"
  console.log 'You are in: ' + channels.join(', ')
  console.log 'As well as: ' + groups.join(', ')

  messages = if unreads is 1 then 'message' else 'messages'

  console.log "You have #{unreads} unread #{messages}"


slack.on 'message', (message) ->
  channel = slack.getChannelGroupOrDMByID(message.channel)
  user = slack.getUserByID(message.user)
  response = ''

  {type, ts, text} = message

  channelName = if channel?.is_channel then '#' else ''
  channelName = channelName + if channel then channel.name else 'UNKNOWN_CHANNEL'

  userName = if user?.name? then "@#{user.name}" else "UNKNOWN_USER"
  userEmail = if user?.name? then "@#{user.profile.email}" else "UNKNOWN_EMAIL"
  
  console.log "User Email : #{userEmail}"

  console.log """
    Received: #{type} #{channelName} #{userName} #{ts} "#{text}"
  """
  # credentials to connect to visual studio team services using basic http authentication     
  username =  process.env.VSO_USERNAME
  password =  process.env.VSO_PASSWORD

  # The Base Url for visual studio team services
  vsoBaseUrl = process.env.VSO_BASEURL 
  
  # The regular expression to check if task number pattern exists in message
  taskExpanderRegex = /task #(\d{1,9})(.*)/i
  
  # The regular expression to check if vsts build trigger pattern exists in message
  vstsBuildTriggerRegex = /#triggerbuild (\d{1,9})(.*)/i
  
  # base64 encode username:password, which will be added to the Authorization heder for basic authentication
  auth = 'Basic ' + new Buffer(username + ':' + password).toString('base64')
            
 
  
  # Respond to messages with details of Visual studio team services task
  if type is 'message' and text? and channel?
    
    messageTaskExpanderMatch = taskExpanderRegex.test(text)
    messageBuildTriggerMatch = vstsBuildTriggerRegex.test(text)
    
    # ***************Pull Task Details from VSTS
    if messageTaskExpanderMatch is true
      console.log "Taskid mentioned in message"
      strmatch = text.match(taskExpanderRegex)
      taskid = strmatch[1]
      console.log taskid
    
      url = "#{vsoBaseUrl}/DefaultCollection/_apis/wit/workItems/#{taskid}" 
  
      
      request.get {
        url: url
        headers: 'Authorization': auth
      }, (error, response, body) ->
        body = body.replace "System.TeamProject" , "TeamProject"
        body = body.replace "System.State" , "State"
        body = body.replace "System.CreatedBy" , "CreatedBy"
        
        json = JSON.parse(body)
        
                
        # check if task id value exists in Visual Studio team services        
        if json.fields != undefined
          console.log "   <b>Task</b>: #{json.id}\n
          Team Project Name: #{json.fields.TeamProject}\n"
          
          # Send Task Details to Channel       
          channel.send ">>>   *Task* : #{json.id}, *State*: #{json.fields.State}\n
          *Project Name*: #{json.fields.TeamProject}, *Created By*: #{json.fields.CreatedBy}\n
          *View / Edit Task* : #{vsoBaseUrl}/DefaultCollection/#{encodeURI(json.fields.TeamProject)}/_workitems/edit/#{taskid}\n"  
                    
        else
          # send task not found message to channel
          channel.send ">>> *No Task with Id '#{taskid}' exists in the configured visual studio team services account*"
          
          
    # ***************Process Build Trigger request        
    else if messageBuildTriggerMatch is true
      console.log "Build trigger request found in message"
      strmatch = text.match(vstsBuildTriggerRegex)
      buildDefinitionId = strmatch[1]
      console.log "Build Definition is #{buildDefinitionId} "
      defaultProject = process.env.DEFAULT_PROJECT
      buildTriggerUrl = "#{vsoBaseUrl}/defaultcollection/#{defaultProject}/_apis/build/builds?api-version=2.0"
      
      
      # Email id from slack starts with @, to pass this to build admin validation API remote the @
      buildAdminEmail = userEmail.replace "@", ""
      
      # set variables needed to communicate with the AD API to check if the user has permission to execute build    
      console.log "AdminEmail : #{buildAdminEmail}"
      buildApiUser = process.env.BUILD_API_USER
      buildApiPass = process.env.BUILD_API_PASS
      adApiAuth = 'Basic ' + new Buffer(buildApiUser + ':' + buildApiPass).toString('base64')
      buildAdminValidationBaseUrl = process.env.BUILD_API_BASE_URL
      buildAdminValidationUrl = "#{buildAdminValidationBaseUrl}?user=#{buildAdminEmail}&project=#{defaultProject}"
      
      console.log "BuildAdminURL : #{buildAdminValidationUrl} "
      # send http post request to vsts build trigger endpoint
      # TODO validate if user has permissions to trigger a build using API (API app which talks to graph APIs)
      request.get {
        url: buildAdminValidationUrl
        headers: 'Authorization': adApiAuth
      }, (error, response, body) ->
        console.log "Response Status : #{response.statusCode}"
        console.log "REsponse Body : #{body}"
        isBuildAdmin = if body == "true" then true else false
        console.log "Build Admin Validation flag : #{isBuildAdmin}"
        if isBuildAdmin is true 
          request.post {
              url: buildTriggerUrl
              headers: {
              'Content-Type': 'application/json',
              'Authorization': auth
                          }
              body: "{  'definition': {    'id': #{buildDefinitionId}  },  'sourceBranch': 'refs/heads/master'}"
          }, (error, response, body) ->
            json = JSON.parse(body)
                
            if json.queueTime != undefined
              console.log "   <b>queueTime</b>: #{json.queueTime}\n
              buildNumber: #{json.buildNumber}\n"
                
              # Send Build Queue Details to Channel       
              channel.send ">>>   Build Number *#{json.buildNumber}* for build definition *#{buildDefinitionId}* has been queued\n
              Queue Time:*#{json.queueTime}*"  
        else 
          channel.send ">>> *#{userName} you are not authorized to trigger a build under the project #{defaultProject}*" 
        
  else
    #this one should probably be impossible, since we're in slack.on 'message' 
    typeError = if type isnt 'message' then "unexpected type #{type}." else null
    #Can happen on delete/edit/a few other events
    textError = if not text? then 'text was undefined.' else null
    #In theory some events could happen with no channel
    channelError = if not channel? then 'channel was undefined.' else null

    #Space delimited string of my errors
    errors = [typeError, textError, channelError].filter((element) -> element isnt null).join ' '

    console.log """
      @#{slack.self.name} could not respond. #{errors}
    """

slack.on 'error', (error) ->
  console.error "Error: #{error}"

slack.login()
