import Foundation

final class PinnedURLSessionDelegate: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        
        // Get the public key from the server's certificate
        let policies = [SecPolicyCreateSSL(true, challenge.protectionSpace.host as CFString)]
        SecTrustSetPolicies(serverTrust, policies as CFTypeRef)
        
        var error: CFError?
        let isTrusted = SecTrustEvaluateWithError(serverTrust, &error)
        
        guard isTrusted, error == nil else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        // Get the public key data to compare against pinned keys
        guard let certificate = SecTrustGetCertificateAtIndex(serverTrust, 0) else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        let serverPublicKey = SecCertificateCopyKey(certificate)
        let serverPublicKeyData = SecKeyCopyExternalRepresentation(serverPublicKey!, nil)
        
        guard let serverKeyData = serverPublicKeyData as Data? else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        // Pinned public key (SPKI hash for Bluesky PDS)
        // This is a placeholder — in production, extract the actual SPKI hash
        let pinnedKeys: [Data] = []
        
        if pinnedKeys.isEmpty || pinnedKeys.contains(serverKeyData) {
            completionHandler(.performDefaultHandling, nil)
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}
