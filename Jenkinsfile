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
                    dir("${params.ENV}") {   // 👈 dynamically use selected env folder
                        sh 'terraform init -reconfigure'
                    }
                }
            }
        }

        stage('Terraform Plan') {
            steps {
                ansiColor('xterm') {
                    dir("${params.ENV}") {
                        sh 'terraform plan -out=tfplan'
                        sh 'terraform show tfplan'
                    }
                }
            }
        }

        stage('Approval') {
            steps {
                script {
                    input message: "Do you want to apply Terraform changes for ${params.ENV}?", ok: "Yes, Apply"
                }
            }
        }

        stage('Terraform Apply') {
            steps {
                ansiColor('xterm') {
                    dir("${params.ENV}") {
                        sh 'terraform apply -auto-approve tfplan'
                    }
                }
            }
        }
    }
}
