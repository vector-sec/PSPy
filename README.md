# AWS PowerShell Python Lambda - PSPy

AWS PowerShell Python Lambda, or PSPy for short, is a simple Python 2.7 AWS Lambda function designed to execute the PowerShell binary and marshal input/output to PowerShell.

## Setup
Setup is very easy depending on your level of trust with a random GitHub repository you found on the internet.

##### Quickstart
If you prefer to get started right away, use GitHub's download zip feature and upload the zip file as the code for a new Lambda function in your AWS account.

##### Build from scratch
Alternatively, if you want to ensure you are getting the latest PowerShell release, and that nothing else is packaged with it [nothing is, I promise :) ] then follow the steps below.
1. Create a new Amazon Linux EC2 instance and run the following commands on it (note you can replace the rpm with the latest release if you desire)
```sh
wget https://github.com/PowerShell/PowerShell/releases/download/v6.0.0-alpha.18/powershell-6.0.0_alpha.18-1.el7.centos.x86_64.rpm
yum install libunwind uuid
rpm -i powershell-6.0.0_alpha.18-1.el7.centos.x86_64.rpm
mkdir pspy
cd pspy
cp -R /opt/microsoft/powershell/6.0.0-alpha.18/* .
cp /usr/lib64/libunwind* .
cp /usr/bin/uuid .
```
2. Create lambda_function.py within the pspy folder containing the code below
```python
import boto3,subprocess,os
def lambda_handler(event, context):
    #get lambda variables
    executionArg = event['executionArg']
    executionPayload = event['executionPayload']
    #environment variables required for powershell to start
    os.environ["HOME"] = "/tmp"
    os.environ["PSHOME"] = "/tmp"
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
```
3. Run the following commands
```sh
zip -rq lambda.zip .
aws s3 cp lambda.zip s3://yourbucket/lambda.zip
```
4. Create python 2.7 lambda function referencing your uploaded zip file from s3
5. Make sure that your Lambda can read from a S3 bucket if you desire to execute ps1 files (more on this later)

## Usage
The Python portion of this Lambda function was designed to be very easy to use. It accepts PowerShell code in three ways.
1. Literal commands that you might traditionally use with -command
2. Base64 encoded commands that you might traditionally use with -encodedcommand
3. PS1 script files that you might traditionally use with -file

##### -Command
Simply pass your Lambda function an event that looks like this
```json
{
  "executionArg": "-c",
  "executionPayload": "Get-Host"
}
```

##### -EncodedCommand
Simply pass your Lambda function an event that looks like this
```json
{
  "executionArg": "-enc",
  "executionPayload": "RwBlAHQALQBIAG8AcwB0ADsARQB4AGkAdAA7AA=="
}
```

##### -File
Simply pass your Lambda function an event that looks like this
```json
{
	"executionArg": "-f",
	"executionPayload": {
		"bucket": "<YOUR BUCKET NAME>",
		"key": "<YOUR OBJECT KEY>"
	}
}
```

## I found an issue
Great! I threw this silly thing together rather hastily so it's likely to have issues. Open an issue with the repository explaining what is wrong and we'll see if we can't figure out how to fix the problem. Or you can bring up an issue and the solution in a pull request.

## I have a suggestion
Awesome! Create an issue describing your suggestion, including a pull request if you have decided to take care of implementing your suggestion for me.

## Why on earth did you do this?
In short: I like PowerShell and wanted to run it in AWS Lambda.

I attempted to get it running in native C# code using dotnetcore in Lambda but kept running into issues. I was seeking help on the PowerShell slack team when a gentleman from AWS (who will remain nameless until he consents to being credited) sent me a private message, interested in what I was trying to do. He asked if I had tried to just use the PowerShell binary in Lambda, so I decided I would give his suggestion a shot and it totally worked!

## License
PSPy is licensed under the MIT license, just like [PowerShell](https://github.com/PowerShell/PowerShell/blob/master/LICENSE.txt)

