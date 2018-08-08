import boto3,subprocess,os
def lambda_handler(event, context):
    #get lambda variables
    executionArg = event['executionArg']
    executionPayload = event['executionPayload']
    #environment variables required for powershell to start
    os.environ["HOME"] = "/tmp"
    os.environ["PSHOME"] = "/tmp"
    #need to make powershell binary executable
    process = subprocess.Popen(["/bin/chmod +x /var/task/powershell"],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,shell=True)
    if executionArg == "-c":
        process = subprocess.Popen(["/var/task/powershell -c '{}'".format(executionPayload)],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,shell=True)
    elif executionArg == "-enc":
        process = subprocess.Popen(["/var/task/powershell -enc {}".format(executionPayload)],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,shell=True)
    elif executionArg == "-f":
        s3_client = boto3.client('s3')
        bucket = executionPayload['bucket']
        key = executionPayload['key']
        localPath = os.path.join('/tmp',key.split("/")[-1])
        s3_client.download_file(bucket, key, localPath)
        process = subprocess.Popen(["/var/task/powershell -f {}".format(localPath)],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,shell=True)
    else:
        return "Unrecognized executionArg"
    returncode = process.wait()
    output = process.stdout.read()
    print output
    return output
