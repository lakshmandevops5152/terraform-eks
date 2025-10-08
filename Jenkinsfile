pipeline {
    agent any

    
    stages {
        stage('Checkout') {
            steps {
                git branch: 'main', url: 'https://github.com/lakshmandevops5152/terraform-eks.git'
            }
        }

        stage('Terraform Init') {
            steps {
                ansiColor('xterm') {
                     {   // 👈 dynamically use selected env folder
                        sh 'terraform init'
                        sh 'terraform plan'
                    }
                }
            }
        }

        
