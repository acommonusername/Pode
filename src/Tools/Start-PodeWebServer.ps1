
function Start-PodeWebServer
{
    try
    {
        # create the listener
        $listener = New-Object System.Net.HttpListener
        $prefix = "http://*:$($PodeSession.Port)/"
        $listener.Prefixes.Add($prefix)

        # start listener
        $listener.Start()

        # state where we're running
        #Write-Warning "Note that thread is blocked waiting for a request.  After using Ctrl-C to stop listening, you need to send a valid HTTP request to stop the listener cleanly."
        #Write-Warning "Sending 'exit' command will cause listener to stop immediately"
        Write-Host "Listening on http://localhost:$($PodeSession.Port)/" -ForegroundColor Yellow

        # loop for http request
        while ($true)
        {
            # get request and response
            $context = $listener.GetContext()
            $request = $context.Request
            $response = $context.Response

            # check for exit command (need to remove this...)
            $command = $request.QueryString.Item("command")
            if ($command -ieq "exit")
            {
                Write-Host "Received command to exit listener"
                $response.OutputStream.Close()
                return
            }

            # get url path and method
            $path = ($request.RawUrl -isplit "\?")[0]
            $method = $request.HttpMethod.ToLowerInvariant()

            # check to see if the path is a file, so we can check the public folder
            if ((Split-Path -Leaf -Path $path).IndexOf('.') -ne -1)
            {
                $path = (Join-Path 'public' $path)
                Write-ToResponseFromFile $path $response
            }

            else
            {
                # ensure the path has a route
                if ($PodeSession.Routes[$method][$path] -eq $null)
                {
                    $response.StatusCode = 404
                }

                # run the scriptblock
                else
                {
                    # read and parse any post data
                    $stream = $request.InputStream
                    $reader = New-Object -TypeName System.IO.StreamReader -ArgumentList $stream, $request.ContentEncoding
                    $data = $reader.ReadToEnd()
                    $reader.Close()

                    switch ($request.ContentType)
                    {
                        { $_ -ilike '*json*' }
                            {
                                $data = ($data | ConvertFrom-Json)
                            }

                        { $_ -ilike '*xml*' }
                            {
                                $data = ($data | ConvertFrom-Xml)
                            }
                    }

                    # invoke route
                    Invoke-Command -ScriptBlock $PodeSession.Routes[$method][$path] -ArgumentList $response, $request, $data
                }
            }

            # close response stream
            $response.OutputStream.Close()
        }
    }
    finally
    {
        if ($listener -ne $null)
        {
            $listener.Stop()
        }
    }
}