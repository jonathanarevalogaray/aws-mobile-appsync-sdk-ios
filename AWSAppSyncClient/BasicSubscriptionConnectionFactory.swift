//
// Copyright 2019 Amazon.com, Inc. or its affiliates. All Rights Reserved.
// Licensed under the Amazon Software License
// http://aws.amazon.com/asl/
//

import Foundation

class BasicSubscriptionConnectionFactory: SubscriptionConnectionFactory {

    var apiKeyBasedPool: APIKeyBasedConnectionPool?
    var userpoolsBasedPool: UserPoolsBasedConnectionPool?
    var iamBasedPool: IAMBasedConnectionPool?
    var oidcBasedPool: OIDCBasedConnectionPool?

    let url: URL
    let retryStrategy: AWSAppSyncRetryStrategy
    let authType: AWSAppSyncAuthType

    init (url: URL,
          authType: AWSAppSyncAuthType,
          retryStrategy: AWSAppSyncRetryStrategy,
          region: AWSRegionType?,
          apiKeyProvider: AWSAPIKeyAuthProvider?,
          cognitoUserPoolProvider: AWSCognitoUserPoolsAuthProvider?,
          oidcAuthProvider: AWSOIDCAuthProvider?,
          iamAuthProvider: AWSCredentialsProvider?) {

        self.url = url
        self.authType = authType
        self.retryStrategy = retryStrategy

        if let apiKeyProvider = apiKeyProvider {
            let authInterceptor = APIKeyAuthInterceptor(apiKeyProvider)
            self.apiKeyBasedPool = APIKeyBasedConnectionPool(authInterceptor)
        }
        if let cognitoUserPoolProvider = cognitoUserPoolProvider {
            let authInterceptor = CognitoUserPoolsAuthInterceptor(cognitoUserPoolProvider)
            self.userpoolsBasedPool = UserPoolsBasedConnectionPool(authInterceptor)
        }
        if let iamAuthProvider = iamAuthProvider, let awsRegion = region {
            let authInterceptor = IAMAuthInterceptor(iamAuthProvider, region: awsRegion)
            self.iamBasedPool = IAMBasedConnectionPool(authInterceptor)
        }
        if let oidcAuthProvider = oidcAuthProvider {
            let authInterceptor = CognitoUserPoolsAuthInterceptor(oidcAuthProvider)
            self.oidcBasedPool = OIDCBasedConnectionPool(authInterceptor)
        }
    }

    func connection(connectionType: SubscriptionConnectionType) -> SubscriptionConnection? {
        let connection = connectionPool(for: authType)?.connection(for: url, connectionType: connectionType)
        if let retryableConnection = connection as? RetryableConnection {
            let retryHandler = AWSAppSyncRetryHandler(retryStrategy: retryStrategy)
            retryableConnection.addRetryHandler(handler: retryHandler)
        }
        return connection
    }

    func connection(for url: URL, authType: AWSAppSyncAuthType, connectionType: SubscriptionConnectionType) -> SubscriptionConnection? {
        return connectionPool(for: authType)?.connection(for: url, connectionType: connectionType)
    }

    // MARK: - Private Methods
    private func connectionPool(for authType: AWSAppSyncAuthType) -> SubscriptionConnectionPool? {
        switch authType {
        case .apiKey:
            return apiKeyBasedPool
        case .awsIAM:
            return iamBasedPool
        case .amazonCognitoUserPools:
            return userpoolsBasedPool
        case .oidcToken:
            return oidcBasedPool
        }
    }
}
