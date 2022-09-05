install-macosx:
	brew install cfssl

ca := ca
intermediate_ca := intermediate_ca
chain_ca := chain_ca
chain := chain
current_ca := $(intermediate_ca)
config := config/profile.json
serve:
	 cfssl serve -ca $(current_ca).pem -ca-key $(current_ca)-key.pem -config $(config)

create-csr:
	cfssl ???

ca:
	cfssl gencert -initca config/$(ca).json | cfssljson -bare $(ca)
	openssl x509 -in $(ca).pem -text -noout

intermediate-ca: ca
	cfssl gencert -initca config/$(intermediate_ca).json | cfssljson -bare $(intermediate_ca)
	cfssl sign -ca $(ca).pem -ca-key $(ca)-key.pem -config $(config) -profile $(intermediate_ca) $(intermediate_ca).csr | cfssljson -bare $(intermediate_ca)
	openssl x509 -in $(intermediate_ca).pem -text -noout

chain-ca: intermediate-ca
	cat $(ca).pem $(intermediate_ca).pem > $(chain_ca).pem

host := demohost
server := $(host)-server
demohost: intermediate-ca
	cfssl gencert -ca $(intermediate_ca).pem -ca-key $(intermediate_ca)-key.pem -config $(config) -profile=peer   config/$(host).json | cfssljson -bare $(host)-peer
	cfssl gencert -ca $(intermediate_ca).pem -ca-key $(intermediate_ca)-key.pem -config $(config) -profile=server config/$(host).json | cfssljson -bare $(server)

client := $(host)-client
democlient: demohost
	cfssl gencert -ca $(server).pem -ca-key $(server)-key.pem -config $(config) -profile=client config/$(host).json | cfssljson -bare $(client)

chain: chain-ca
	cat $(chain_ca).pem $(server).pem > $(chain).pem

verify-server: demohost chain-ca
	openssl verify -CAfile $(chain_ca).pem $(server).pem

verify-client: democlient chain
	openssl x509 -in $(client).pem -text -noout
	openssl verify -CAfile $(chain).pem $(client).pem

demo: clean democlient
	ls -la $(ca)*
	ls -la $(intermediate_ca)*
	ls -la $(host)*

clean:
	rm -rf *.pem *.csr
