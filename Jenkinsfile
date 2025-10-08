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
                        terraform plan -out=tfplan
                    '''
                }
            }
        }

        stage('Approval') {
            steps {
                script {
                    def userInput = input(
                        id: 'Proceed1', message: 'Do you want to apply the Terraform changes?', parameters: [
                            [$class: 'BooleanParameterDefinition', defaultValue: false, description: 'Approve to apply Terraform plan', name: 'Approved']
                        ]
                    )
                    if (!userInput) {
                        error("Terraform apply was not approved. Pipeline stopped.")
                    }
                }
            }
        }

        stage('Terraform Apply') {
            when {
                expression { return true } // runs only if approved
            }
            steps {
                ansiColor('xterm') {
                    sh 'terraform apply -auto-approve tfplan'
                }
            }
        }
    }
}
