pipeline {
    agent any

    stages {
        stage('Checkout') {
            steps {
                git branch: 'main', url: 'https://github.com/lakshmandevops5152/terraform-eks.git'
            }
        }

        stage('Terraform Init & Plan') {
            steps {
                ansiColor('xterm') {
                    sh '''
                        terraform init
                        terraform plan
                    '''
                }
            }
        }
    }
}
