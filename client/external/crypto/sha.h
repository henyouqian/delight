#ifndef SHA_H
#define SHA_H

#include <stdint.h>
#include <string>

struct sha1nfo;

class Sha1 {
public:
    Sha1();
    ~Sha1();
    void write(const char *data, size_t len);
    void final();
    const char* getResult();
    const char* getBase64();
    
private:
    sha1nfo *_info;
    uint8_t *_resbuf;
    std::string _result;
    std::string _base64;
};

#endif /* SHA_H */