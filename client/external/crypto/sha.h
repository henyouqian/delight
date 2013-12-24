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
    
private:
    std::string _result;
    sha1nfo *_info;
};

#endif /* SHA_H */